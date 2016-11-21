module ActiveMerchant
  module Billing

    KB_PLUGIN_VERSION = Gem.loaded_specs['killbill-orbital'].version.version rescue nil

    class OrbitalGateway

      def store(creditcard, options = {})
        add_customer_profile(creditcard, options)
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

      def add_creditcard(xml, creditcard, currency=nil)
        unless creditcard.nil?
          xml.tag! :AccountNum, creditcard.number
          xml.tag! :Exp, expiry_date(creditcard)
        end

        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, currency_exponents(currency)

        # Do not include the CardSecValInd if verification_value is not present because CC flow does not try to collect this information
        # - http://download.chasepaymentech.com/docs/orbital/orbital_gateway_xml_specification.pdf
        unless creditcard.nil?
          if %w( visa discover ).include?(creditcard.brand)
            xml.tag! :CardSecValInd, '1' if creditcard.verification_value?
          end
          xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.verification_value?
        end
      end

    end
  end
end
