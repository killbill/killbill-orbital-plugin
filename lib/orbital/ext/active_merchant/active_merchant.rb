module ActiveMerchant
  module Billing

    KB_PLUGIN_VERSION = Gem.loaded_specs['killbill-orbital'].version.version rescue nil

    class OrbitalGateway

      API_VERSION = '7.0.1'

      POST_HEADERS = {
          "MIME-Version" => "1.1",
          "Content-Type" => "application/PTI70",
          "Content-transfer-encoding" => "text",
          "Request-number" => '1',
          "Document-type" => "Request",
          "Interface-Version" => "Ruby|ActiveMerchant|Proprietary Gateway"
      }

      def store(creditcard, options = {})
        response = add_customer_profile(creditcard, options)

        # Workaround: unmask the PAN if needed
        # TODO We could call on-the-fly retrieve_customer_profile instead in PaymentPlugin#get_payment_source to
        # avoid having to store the PAN, but this requires a specific merchant account setting
        response.params['cc_account_num'] = creditcard.number if response.params['cc_account_num'].starts_with?('XXXX')

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
                                     'Interface-Version' => 'Ruby|KillBill|Open-Source Gateway')
        headers['X-Request-Id'] = x_r_id unless x_r_id.blank?
        headers.merge!('Trace-number' => trace_number.to_s,
                       'Merchant-Id' => @options[:merchant_id]) if @options[:retry_logic] && trace_number
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
                         :cvv_result => OrbitalGateway::CVVResult.new(response[:cvv2_resp_code])
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

            xml.tag! :OrderID, format_order_id(parameters[:order_id])
            xml.tag! :Amount, amount(money)
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]

            # Add additional card information for tokenized credit card that must be placed after the above three elements
            add_addtional_network_tokenization(xml, parameters[:creditcard]) unless parameters[:creditcard].nil?

            if parameters[:soft_descriptors].is_a?(OrbitalSoftDescriptors)
              add_soft_descriptors(xml, parameters[:soft_descriptors])
            end

            set_recurring_ind(xml, parameters)

            # Append Transaction Reference Number at the end for Refund transactions
            if action == REFUND
              tx_ref_num, _ = split_authorization(parameters[:authorization])
              xml.tag! :TxRefNum, tx_ref_num
            end
          end
        end
        xml.target!
      end

      # A – Authorization request
      def authorize(money, creditcard, options = {})
        order = build_new_order_xml(AUTH_ONLY, money, options.merge(:creditcard=>creditcard)) do |xml|
          add_creditcard(xml, creditcard, options)
          add_address(xml, creditcard, options)
          if @options[:customer_profiles]
            add_customer_data(xml, creditcard, options)
            add_managed_billing(xml, options)
          end
          add_network_tokenization(xml, creditcard)
        end
        commit(order, :authorize, options[:trace_number])
      end

      # AC – Authorization and Capture
      def purchase(money, creditcard, options = {})
        order = build_new_order_xml(AUTH_AND_CAPTURE, money, options.merge(:creditcard=>creditcard)) do |xml|
          add_creditcard(xml, creditcard, options)
          add_address(xml, creditcard, options)
          if @options[:customer_profiles]
            add_customer_data(xml, creditcard, options)
            add_managed_billing(xml, options)
          end
          add_network_tokenization(xml, creditcard)
        end
        commit(order, :purchase, options[:trace_number])
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
        xml.tag!('AuthenticationECIInd', payment_method.eci) if payment_method.eci.nil?
        xml.tag!('CAVV', payment_method.payment_cryptogram) if card_brand == :visa
      end

      def add_addtional_network_tokenization(xml, payment_method)
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

    end
  end
end
