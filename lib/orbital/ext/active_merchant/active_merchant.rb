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
    end
  end
end
