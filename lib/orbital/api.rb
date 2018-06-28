module Killbill #:nodoc:
  module Orbital #:nodoc:
    class PaymentPlugin < ::Killbill::Plugin::ActiveMerchant::PaymentPlugin
      FIVE_MINUTES_AGO = (5 * 60)
      ONE_HOUR_AGO = (1 * 3600)

      def initialize
        gateway_builder = Proc.new do |config|
          ::ActiveMerchant::Billing::OrbitalGateway.new :login => config[:login],
                                                        :password => config[:password],
                                                        # ActiveMerchant expects it to be a String
                                                        :merchant_id => config[:merchant_id].to_s
        end

        super(gateway_builder,
              :orbital,
              ::Killbill::Orbital::OrbitalPaymentMethod,
              ::Killbill::Orbital::OrbitalTransaction,
              ::Killbill::Orbital::OrbitalResponse)
      end

      def on_event(event)
        # Require to deal with per tenant configuration invalidation
        super(event)
        #
        # Custom event logic could be added below...
        #
      end

      def authorize_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        options = {:mit_reference_trx_id => find_mit_ref_trx_id_if_needed(properties)}
        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context, with_trace_num_and_order_id(properties))
      end

      def capture_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = properties_to_hash properties
        if options[:force_capture]
          last_auth_response = @response_model.send('auth_responses_from_kb_payment_id', kb_payment_id, context.tenant_id).last
          raise "Unable to retrieve last authorization for operation=capture, kb_payment_id=#{kb_payment_id}, kb_payment_transaction_id=#{kb_payment_transaction_id}, kb_payment_method_id=#{kb_payment_method_id}" if last_auth_response.nil?
          options[:payment_processor_account_id] = last_auth_response.payment_processor_account_id
          options[:prior_auth_id] = last_auth_response.params_auth_code
          options[:order_id] = last_auth_response.second_reference_id if options[:order_id].nil?
          purchase_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, hash_to_properties(options), context)
        else
          super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context, with_trace_num_and_order_id(properties))
        end
      end

      def purchase_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        options = {:mit_reference_trx_id => find_mit_ref_trx_id_if_needed(properties)}
        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context, with_trace_num_and_order_id(properties))
      end

      def void_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, properties, context, with_trace_num_and_order_id(properties))
      end

      def credit_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context, with_trace_num_and_order_id(properties))
      end

      def refund_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context, with_trace_num_and_order_id(properties))
      end

      def get_payment_info(kb_account_id, kb_payment_id, properties, context)
        options = properties_to_hash(properties)

        plugin_trxs_info = super(kb_account_id, kb_payment_id, properties, context)
        return super(kb_account_id, kb_payment_id, properties, context) if try_fix_undefined_trxs(plugin_trxs_info, options, context)
        plugin_trxs_info
      end

      def search_payments(search_key, offset, limit, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(search_key, offset, limit, properties, context)
      end

      def add_payment_method(kb_account_id, kb_payment_method_id, payment_method_props, set_default, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_method_id, payment_method_props, set_default, properties, context)
      end

      def delete_payment_method(kb_account_id, kb_payment_method_id, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_method_id, properties, context)
      end

      def get_payment_method_detail(kb_account_id, kb_payment_method_id, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_method_id, properties, context)
      end

      def set_default_payment_method(kb_account_id, kb_payment_method_id, properties, context)
        # TODO
      end

      def get_payment_methods(kb_account_id, refresh_from_gateway, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, refresh_from_gateway, properties, context)
      end

      def search_payment_methods(search_key, offset, limit, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(search_key, offset, limit, properties, context)
      end

      def reset_payment_methods(kb_account_id, payment_methods, properties, context)
        super
      end

      private

      def try_fix_undefined_trxs(plugin_trxs_info, options, context)
        stale = false
        plugin_trxs_info.each do |plugin_trx_info|
          next unless should_try_to_fix_trx plugin_trx_info, options
          stale = true if fix_undefined_trx plugin_trx_info, context, options
        end
        stale
      end

      def should_try_to_fix_trx(plugin_trx_info, options)
        plugin_trx_info.status == :UNDEFINED && pass_delay_time(plugin_trx_info, options)
      end

      def fix_undefined_trx(plugin_trx_info, context, options)
        inquiry_response = inquiry(plugin_trx_info, context)
        update_response_if_needed plugin_trx_info, inquiry_response, options
      end

      def update_response_if_needed(plugin_trx_info, inquiry_response, options)
        response_id = find_value_from_properties(plugin_trx_info.properties, 'orbital_response_id')
        response = OrbitalResponse.find_by(:id => response_id)
        updated = false
        if should_update_response inquiry_response, plugin_trx_info
          logger.info("Fixing UNDEFINED kb_transaction_id='#{plugin_trx_info.kb_transaction_payment_id}', success='#{inquiry_response.success?}'")
          response.update_and_create_transaction(inquiry_response)
          updated = true
        elsif should_cancel_payment plugin_trx_info, options
          @logger.info("Canceling UNDEFINED kb_transaction_id='#{plugin_trx_info.kb_transaction_payment_id}'")
          response.cancel
          updated = true
        end
        updated
      end

      def should_update_response(inquiry_response, plugin_trx_info)
        !inquiry_response.nil? && !inquiry_response.params.nil? && inquiry_response.params['order_id'] == plugin_trx_info.second_payment_reference_id
      end

      def should_cancel_payment(plugin_trx_info, options)
        threshold = (Killbill::Plugin::ActiveMerchant::Utils.normalized(options, :cancel_threshold) || ONE_HOUR_AGO).to_i
        delay_since_trx(plugin_trx_info) >= threshold
      end

      def pass_delay_time(plugin_trx_info, options)
        janitor_delay_threshold = (Killbill::Plugin::ActiveMerchant::Utils.normalized(options, :janitor_delay_threshold) || FIVE_MINUTES_AGO).to_i
        delay_since_trx(plugin_trx_info) >= janitor_delay_threshold
      end

      def delay_since_trx(plugin_trx_info)
        delay_since_transaction = now - plugin_trx_info.created_date
        delay_since_transaction < 0 ? 0 : delay_since_transaction
      end

      def now
        Time.parse(@clock.get_clock.get_utc_now.to_s)
      end

      def inquiry(plugin_trx_info, context)
        payment_processor_account_id = find_value_from_properties(plugin_trx_info.properties, 'payment_processor_account_id')
        trace_number = find_value_from_properties(plugin_trx_info.properties, 'trace_number')
        orbital_order_id = plugin_trx_info.second_payment_reference_id

        return nil if trace_number.nil? || orbital_order_id.nil? || payment_processor_account_id.nil?

        gateway = lookup_gateway(payment_processor_account_id, context.tenant_id)
        gateway.inquiry(orbital_order_id, trace_number)
      end

      def with_trace_num_and_order_id(properties)
        {:params_trace_number => find_value_from_properties(properties, :trace_number),
         :params_order_id => find_value_from_properties(properties, :order_id)}.delete_if{|_, value| value.blank?}
      end

      def find_mit_ref_trx_id_if_needed(properties)
        ref_trx_id = find_value_from_properties(properties, :mit_ref_trx_id)
        return nil if ref_trx_id.nil?
        return @response_model.send('find_cit_transaction_ref_id', kb_trx_id, context.tenant_id)
      end
    end
  end
end
