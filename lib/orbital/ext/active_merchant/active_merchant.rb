module ActiveMerchant
  module Billing

    KB_PLUGIN_VERSION = Gem.loaded_specs['killbill-orbital'].version.version rescue nil

    class OrbitalGateway

      API_VERSION = '7.0.1'

      def store(creditcard, options = {})
        response = add_customer_profile(creditcard, options)

        # Workaround: unmask the PAN if needed
        # TODO We could call on-the-fly retrieve_customer_profile instead in PaymentPlugin#get_payment_source to
        # avoid having to store the PAN, but this requires a specific merchant account setting
        response.params['cc_account_num'] = creditcard.number if response.params['cc_account_num'].include?('XXXX')

        response
      end

      def user_agent
        @@ua ||= JSON.dump({
                               :bindings_version => KB_PLUGIN_VERSION,
                               :lang => 'ruby',
                               :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
                               :platform => RUBY_PLATFORM,
                               :publisher => 'killbill'
                           })
      end

      def x_request_id
        # See KillbillMDCInsertingServletFilter
        org::slf4j::MDC::get('req.requestId') rescue nil
      end

      def commit(order, message_type, trace_number=nil)
        x_r_id = x_request_id

        headers = POST_HEADERS.merge('Content-length' => order.size.to_s,
                                     'User-Agent' => user_agent,
                                     'Interface-Version' => 'Ruby|KillBill|Open-Source Gateway',
                                     'Content-Type' => 'application/PTI70')
        headers['X-Request-Id'] = x_r_id unless x_r_id.blank?
        headers.merge!('Trace-number' => trace_number.to_s,
                       'Merchant-Id' => @options[:merchant_id]) if trace_number
        request = lambda { |url| parse(ssl_post(url, order, headers)) }

        # Failover URL will be attempted in the event of a connection error
        response = begin
          request.call(remote_url)
        rescue ConnectionError
          request.call(remote_url(:secondary))
        end

        Response.new(success?(response, message_type),
                     message_from(response),
                     response,
                     {
                         :authorization => authorization_string(response[:tx_ref_num], response[:order_id]),
                         :test => self.test?,
                         :avs_result => OrbitalGateway::AVSResult.new(response[:avs_resp_code]),
                         :cvv_result => OrbitalGateway::CVVResult.new(response[:cvv2_resp_code]),
                     })
      end

      def build_new_order_xml(action, money, parameters = {})
        requires!(parameters, :order_id)
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :NewOrder do
            add_xml_credentials(xml)
            # EC - Ecommerce transaction
            # RC - Recurring Payment transaction
            # MO - Mail Order Telephone Order transaction
            # IV - Interactive Voice Response
            # IN - Interactive Voice Response
            xml.tag! :IndustryType, parameters[:industry_type] || ECOMMERCE_TRANSACTION
            # A  - Auth Only No Capture
            # AC - Auth and Capture
            # F  - Force Auth No Capture and no online authorization
            # FR - Force Auth No Capture and no online authorization
            # FC - Force Auth and Capture no online authorization
            # R  - Refund and Capture no online authorization
            xml.tag! :MessageType, action
            add_bin_merchant_and_terminal(xml, parameters)

            yield xml if block_given?

            xml.tag! :PriorAuthID, parameters[:prior_auth_id] if parameters[:prior_auth_id]
            xml.tag! :OrderID, format_order_id(parameters[:order_id])
            xml.tag! :Amount, amount(money)
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]

            # Add additional card information for tokenized credit card that must be placed after the above three elements
            if action == AUTH_ONLY || action == AUTH_AND_CAPTURE
              add_additional_network_tokenization(xml, parameters[:creditcard]) unless parameters[:creditcard].nil?
            end

            if parameters[:soft_descriptors].is_a?(OrbitalSoftDescriptors)
              add_soft_descriptors(xml, parameters[:soft_descriptors])
            end

            set_recurring_ind(xml, parameters)

            # Append Transaction Reference Number for Refund transactions
            if action == REFUND && !parameters[:authorization].nil?
              tx_ref_num, _ = split_authorization(parameters[:authorization])
              xml.tag! :TxRefNum, tx_ref_num
            end

            add_mit_cit_params(xml, parameters)
          end
        end
        xml.target!
      end

      # A – Authorization request
      def authorize(money, creditcard, options = {})
        order = build_new_order_xml_with_cc(AUTH_ONLY, money, creditcard, options)
        commit(order, :authorize, options[:trace_number])
      end

      # AC – Authorization and Capture or Force Capture
      def purchase(money, creditcard, options = {})
        if options[:force_capture]
          order = build_new_order_xml_with_cc(FORCE_AUTH_AND_CAPTURE, money, creditcard, options)
          commit(order, :purchase, options[:trace_number])
        else
          order = build_new_order_xml_with_cc(AUTH_AND_CAPTURE, money, creditcard, options)
          commit(order, :purchase, options[:trace_number])
        end
      end

      # MFC - Mark For Capture or Force capture
      def capture(money, authorization, options = {})
        commit(build_mark_for_capture_xml(money, authorization, options), :capture)
      end

      def credit(money, creditcard, options= {})
        order = build_new_order_xml_with_cc(REFUND, money, creditcard, options)
        commit(order, :credit, options[:trace_number])
      end

      def inquiry(order_id, retry_num)
        query = build_inquiry_request(order_id, retry_num, options)
        commit(query, :inquiry, options[:trace_number])
      end

      def build_inquiry_request(order_id, retry_num, options)
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :Inquiry do
            add_xml_credentials(xml)
            add_bin_merchant_and_terminal(xml, options)
            xml.tag! :OrderID, order_id
            xml.tag! :InquiryRetryNumber, retry_num
          end
        end
        xml.target!
      end

      def build_new_order_xml_with_cc(operation, money, creditcard, options)
        build_new_order_xml(operation, money, options.merge(:creditcard=>creditcard)) do |xml|
          add_creditcard(xml, creditcard, options)
          add_address(xml, creditcard, options)
          if @options[:customer_profiles]
            add_customer_data(xml, creditcard, options)
            add_managed_billing(xml, options)
          end
          add_network_tokenization(xml, creditcard)
        end
      end

      def add_mit_cit_params(xml, options)
        options.each {
          |x| puts x
        }
        xml.tag! :MITMsgType, options[:mit_cit_type] unless options[:mit_cit_type].nil?
        unless options[:credential_on_file].nil?
          xml.tag! :MITStoredCredentialInd, (options[:credential_on_file] ? 'Y' : 'N')
        end
        xml.tag! :MITSubmittedTransactionId, options[:mit_reference_trx_id] unless options[:mit_reference_trx_id].nil?
      end

      def add_creditcard(xml, creditcard, options = {})
        currency = options[:currency]
        cvv_indicator_visa_discover = options[:cvv_indicator_visa_discover]
        cvv_indicator_override_visa_discover = options[:cvv_indicator_override_visa_discover]

        unless creditcard.nil?
          xml.tag! :AccountNum, creditcard.number
          xml.tag! :Exp, expiry_date(creditcard)
        end

        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, currency_exponents(currency)

        unless creditcard.nil?
          if %w( visa discover ).include?(creditcard.brand)
            if cvv_indicator_visa_discover
              xml.tag! :CardSecValInd, (creditcard.verification_value? ? '1' : cvv_indicator_override_visa_discover || '9')
            else
              xml.tag! :CardSecValInd, '1' if creditcard.verification_value?
            end
          end
          xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.verification_value?
        end
      end

      def add_network_tokenization(xml, payment_method)
        return unless network_tokenization?(payment_method)
        card_brand = card_brand(payment_method).to_sym

        # The elements must follow a specific sequence
        xml.tag!('AuthenticationECIInd', payment_method.eci) unless payment_method.eci.nil?
        xml.tag!('CAVV', payment_method.payment_cryptogram) if card_brand == :visa
      end

      def add_additional_network_tokenization(xml, payment_method)
        return unless network_tokenization?(payment_method)
        card_brand = card_brand(payment_method).to_sym

        # The elements must follow a specific sequence
        xml.tag!('AAV', payment_method.payment_cryptogram) if card_brand == :master
        xml.tag!('DPANInd', 'Y')
        xml.tag!('AEVV', payment_method.payment_cryptogram) if card_brand == :american_express
        xml.tag!('DigitalTokenCryptogram', payment_method.payment_cryptogram)
      end

      def network_tokenization?(payment_method)
        payment_method.is_a?(NetworkTokenizationCreditCard)
      end

      def success?(response, message_type)
        if [:refund, :void, :credit].include?(message_type)
          response[:proc_status] == SUCCESS
        elsif response[:customer_profile_action]
          response[:profile_proc_status] == SUCCESS
        else
          response[:proc_status] == SUCCESS &&
              APPROVED.include?(response[:resp_code])
        end
      end

      class AVSResult

        # Convert the Orbital's AVS code (See https://github.com/activemerchant/active_merchant/blob/0f6fb4fcb442c310fa21307d9f233fbb56f5c0ad/lib/active_merchant/billing/gateways/orbital.rb#L744)
        # to
        # the 'standard' one (https://www.wellsfargo.com/downloads/pdf/biz/merchant/visa_avs.pdf
        #                     http://en.wikipedia.org/wiki/Address_Verification_System)
        # Note that 2, 8, D, E, UK are not converted because no suitable target codes in the standard codes are found
        CONVERT_MAP = {
            '1'  => 'U', # 'No address supplied' => 'Address information unavailable.'
            '2'  => '2', # Unchanged: 'Bill-to address did not pass Auth Host edit checks'
            '3'  => 'I', # 'AVS not performed' => 'Address not verified.'
            '4'  => 'S', # 'Issuer does not participate in AVS', => 'U.S.-issuing bank does not support AVS.'
            '5'  => 'E', # 'Edit-error - AVS data is invalid', => 'AVS data is invalid or AVS is not allowed for this card type.'
            '6'  => 'R', # 'System unavailable or time-out', => 'System unavailable.'
            '7'  => 'U', # 'Address information unavailable', => 'Address information unavailable.'
            '8'  => '8', # Unchanged: 'Transaction Ineligible for AVS'
            '9'  => 'X', # 'Zip Match/Zip 4 Match/Locale match', => 'Street address and 9-digit postal code match.'
            'A'  => 'W', # 'Zip Match/Zip 4 Match/Locale no match', => 'Street address does not match, but 9-digit postal code matches.'
            'B'  => 'Y', # 'Zip Match/Zip 4 no Match/Locale match', => 'Street address and 5-digit postal code match.'
            'C'  => 'Z', # 'Zip Match/Zip 4 no Match/Locale no match', => 'Street address does not match, but 5-digit postal code matches.'
            'D'  => 'D', # Unchanged: 'Zip No Match/Zip 4 Match/Locale match'
            'E'  => 'E', # Unchanged: 'Zip No Match/Zip 4 Match/Locale no match',
            'F'  => 'A', # 'Zip No Match/Zip 4 No Match/Locale match', => 'Street address matches, but 5-digit and 9-digit postal code do not match.'
            'G'  => 'N', # 'No match at all', => 'Street address and postal code do not match.'
            'H'  => 'Y', # 'Zip Match/Locale match', => 'Street address and 5-digit postal code match.'
            'J'  => 'G', # 'Issuer does not participate in Global AVS', => 'Non-U.S. issuing bank does not support AVS.'
            'JA' => 'D', # 'International street address and postal match', => 'Street address and postal code match'
            'JB' => 'B', # 'International street address match. Postal code not verified', => 'Street address matches, but postal code not verified.'
            'JC' => 'I', # 'International street address and postal code not verified', => 'Address not verified.'
            'JD' => 'P', # 'International postal code match. Street address not verified', => 'Postal code matches, but street address not verified.'
            'M1' => 'K', # 'Cardholder name matches', => 'Card member's name matches but billing address and billing postal code do not match.'
            'M2' => 'V', # 'Cardholder name, billing address, and postal code matches', => 'Card member's name, billing address, and billing postal code match.'
            'M3' => 'L', # 'Cardholder name and billing code matches', => 'Card member's name and billing postal code match, but billing address does not match.'
            'M4' => 'O', # 'Cardholder name and billing address match', => 'Card member's name and billing address match, but billing postal code does not match.	'
            'M5' => 'H', # 'Cardholder name incorrect, billing address and postal code match', => 'Card member's name does not match. Street address and postal code match.	'
            'M6' => 'F', # 'Cardholder name incorrect, billing postal code matches', => 'Card member's name does not match, but billing postal code matches.	'
            'M7' => 'T', # 'Cardholder name incorrect, billing address matches', => 'Card member's name does not match, but street address matches.	'
            'M8' => 'N', # 'Cardholder name, billing address and postal code are all incorrect', => 'Street address and postal code do not match.	'
            'N3' => 'B', # 'Address matches, ZIP not verified', => 'Street address matches, but postal code not verified.	'
            'N4' => 'C', # 'Address and ZIP code not verified due to incompatible formats', => 'Address not verified.	'
            'N5' => 'D', # 'Address and ZIP code match (International only)', => 'Street address and postal code match. '
            'N6' => 'I', # 'Address not verified (International only)', => 'Address not verified.'
            'N7' => 'P', # 'ZIP matches, address not verified', => 'Postal code matches, but street address not verified.	'
            'N8' => 'D', # 'Address and ZIP code match (International only)', => 'Street address and postal code match.'
            'N9' => 'D', # 'Address and ZIP code match (UK only)', => 'Street address and postal code match.'
            'R'  => 'S', # 'Issuer does not participate in AVS', => 'U.S. Bank does not support AVS.	'
            'UK' => 'UK',# Unchanged: UNKNOWN
            'X'  => 'X', # 'Zip Match/Zip 4 Match/Address Match', => 'Street address and 9-digit postal code match.	'
            'Z'  => 'Z'  # 'Zip Match/Locale no match', => 'Street address does not match, but 5-digit postal code matches.	'
        }

        def initialize(code)
          @code = code.blank? ? nil : code.to_s.strip.upcase
          if @code
            @message      = CODES[@code]
            @postal_match = ORBITAL_POSTAL_MATCH_CODE[@code]
            @street_match = ORBITAL_STREET_MATCH_CODE[@code]
            @code         = CONVERT_MAP[@code] unless CONVERT_MAP[@code].nil?
          end
        end
      end
    end
  end
end
