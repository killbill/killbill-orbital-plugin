module Killbill #:nodoc:
  module Orbital #:nodoc:
    class PaymentPlugin < ::Killbill::Plugin::ActiveMerchant::PaymentPlugin
      FIVE_MINUTES_AGO = (5 * 60)
      ONE_HOUR_AGO = (1 * 3600)
      THIRTEEN_MONTHS_AGO = (24 * 60 * 60 * 30 * 13)

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
        options = {:mit_reference_trx_id => find_mit_ref_trx_id_if_needed(find_value_from_properties(properties, :mit_ref_trx_id),
                                                                          context.tenant_id)}
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
        options = {:mit_reference_trx_id => find_mit_ref_trx_id_if_needed(find_value_from_properties(properties, :mit_ref_trx_id),
                                                                          context.tenant_id)}
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
        logger.info("Inside refund payment'#{properties}'")
        credit_opts = properties_to_hash(properties)
        if should_credit?(kb_payment_id, context, credit_opts)
          logger.info("Inside should credit '#{credit_opts}'")
          # Note: from the plugin perspective, this transaction is a CREDIT but Kill Bill doesn't care about PaymentTransactionInfoPlugin#TransactionType
          return credit_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, hash_to_properties(credit_opts), context)
        end
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

      def should_credit?(kb_payment_id, context, options = {})
        logger.info("Inside should credit method '#{options}'")
        transaction = @transaction_model.find_candidate_transaction_for_refund(kb_payment_id, context.tenant_id)
        return false if transaction.nil?

        threshold = (Killbill::Plugin::ActiveMerchant::Utils.normalized(options, :janitor_delay_threshold) || THIRTEEN_MONTHS_AGO).to_i
        options[:payment_processor_account_id] ||= transaction.payment_processor_account_id
        (now - transaction.created_at) >= threshold
      end

      private

      def try_fix_undefined_trxs(plugin_trxs_info, options, context)
        stale = false
        auth_order_id, authorization = find_auth_order_id_and_authorization(plugin_trxs_info)
        plugin_trxs_info.each do |plugin_trx_info|
          next unless should_try_to_fix_trx plugin_trx_info, options
          # Resort to auth order id for scenarios like MarkForCapture where Orbital Order Id is not persisted
          # when remote call fails.
          order_id = plugin_trx_info.second_payment_reference_id.nil? ? auth_order_id : plugin_trx_info.second_payment_reference_id
          stale = true if fix_undefined_trx plugin_trx_info, order_id, authorization, context, options
        end
        stale
      end

      def find_auth_order_id_and_authorization(plugin_trxs_info)
        auth_plugin_info = plugin_trxs_info.find { |info| info.transaction_type == :AUTHORIZE && !info.second_payment_reference_id.nil? }
        if auth_plugin_info.nil?
          return [nil, nil]
        end
        [auth_plugin_info.second_payment_reference_id,
         find_value_from_properties(auth_plugin_info.properties, 'authorization')]
      end

      def should_try_to_fix_trx(plugin_trx_info, options)
        plugin_trx_info.status == :UNDEFINED && pass_delay_time(plugin_trx_info, options)
      end

      def fix_undefined_trx(plugin_trx_info, order_id, authorization, context, options)
        payment_processor_account_id = find_value_from_properties(plugin_trx_info.properties, 'payment_processor_account_id')
        trace_number = find_value_from_properties(plugin_trx_info.properties, 'trace_number')
        return false if trace_number.nil? || order_id.nil? || payment_processor_account_id.nil?

        gateway = lookup_gateway(payment_processor_account_id, context.tenant_id)
        if plugin_trx_info.transaction_type == :CAPTURE
          logger.info("Attempt to fix UNDEFINED capture for kb_transaction_id='#{plugin_trx_info.kb_transaction_payment_id}'")
          response, amount, currency = retry_capture(plugin_trx_info, order_id, authorization, trace_number, context, gateway)
          update_response_if_needed plugin_trx_info, order_id, response, options, amount, currency
        else
          logger.info("Attempt to query UNDEFINED transaction for kb_transaction_id='#{plugin_trx_info.kb_transaction_payment_id}'")
          response = inquiry(order_id, trace_number, gateway)
          update_response_if_needed plugin_trx_info, order_id, response, options
        end
      end

      def update_response_if_needed(plugin_trx_info, order_id, inquiry_response, options, amount = nil, currency = nil)
        response_id = find_value_from_properties(plugin_trx_info.properties, 'orbital_response_id')
        response = OrbitalResponse.find_by(:id => response_id)
        updated = false
        if should_update_response inquiry_response, order_id
          logger.info("Fixing UNDEFINED kb_transaction_id='#{plugin_trx_info.kb_transaction_payment_id}', success='#{inquiry_response.success?}'")
          response.update_and_create_transaction(inquiry_response, amount, currency)
          updated = true
        elsif should_cancel_payment plugin_trx_info, options
          @logger.info("Canceling UNDEFINED kb_transaction_id='#{plugin_trx_info.kb_transaction_payment_id}'")
          response.cancel
          updated = true
        else
          @logger.info("Attempted to fix UNDEFINED kb_transaction_id='#{plugin_trx_info.kb_transaction_payment_id}' but unsuccessful")
        end
        updated
      end

      def should_update_response(inquiry_response, order_id)
        !inquiry_response.nil? && !inquiry_response.params.nil? && inquiry_response.params['order_id'] == order_id
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

      def inquiry(order_id, trace_number, gateway)
        gateway.inquiry(order_id, trace_number)
      end

      def retry_capture(plugin_trx_info, order_id, authorization, trace_number, context, gateway)
        options = {:trace_number => trace_number, :order_id => order_id}

        # Pass a cloned object of context to avoid being modified in get_payment via to_java
        kb_payment = @kb_apis.payment_api.get_payment(plugin_trx_info.kb_payment_id, false, false, [], context.clone)
        kb_transaction = kb_payment.transactions.detect {|trx| trx.id == plugin_trx_info.kb_transaction_payment_id}

        amount = kb_transaction.amount
        currency = kb_transaction.currency
        return [gateway.capture(to_cents(amount, currency),
                                authorization,
                                options),
                amount,
                currency]
      end

      def with_trace_num_and_order_id(properties)
        {:params_trace_number => find_value_from_properties(properties, :trace_number),
         :params_order_id => find_value_from_properties(properties, :order_id)}.delete_if{|_, value| value.blank?}
      end

      def find_mit_ref_trx_id_if_needed(ref_trx_id, tenant_id)
        return nil if ref_trx_id.nil?
        return @response_model.send('find_mit_transaction_ref_id', ref_trx_id, tenant_id)
      end
    end
  end
end
