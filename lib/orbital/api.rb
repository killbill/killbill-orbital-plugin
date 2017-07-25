module Killbill #:nodoc:
  module Orbital #:nodoc:
    class PaymentPlugin < ::Killbill::Plugin::ActiveMerchant::PaymentPlugin

      FIVE_MINUTES_AGO = (1 * 300)

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
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def capture_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def purchase_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def void_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, properties, context)
      end

      def credit_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def refund_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def get_payment_info(kb_account_id, kb_payment_id, properties, context)

        options = properties_to_hash(properties)
        transaction_info_plugins = super(kb_account_id, kb_payment_id, properties, context)

        stale = false
        transaction_info_plugins.each do |transaction_info_plugin|
          # We only need to fix the UNDEFINED ones
          next unless transaction_info_plugin.status == :UNDEFINED

          orbital_response_id = find_value_from_properties(transaction_info_plugin.properties, 'orbitalResponseId')
          if orbital_response_id.nil?
            logger.warn("Unable to fix UNDEFINED kb_transaction_id='#{transaction_info_plugin.kb_transaction_payment_id}' (orbital_response_id not specified)")
            next
          end
          response = OrbitalResponse.find_by(:id => orbital_response_id)
          if response.nil?
            logger.warn("Unable to fix UNDEFINED kb_transaction_id='#{transaction_info_plugin.kb_transaction_payment_id}' (CyberSource response='#{cybersource_response_id}' not found)")
            next
          end

          delay_since_transaction = Time.parse(@clock.get_clock.get_utc_now.to_s) - transaction_info_plugin.created_date
          delay_since_transaction = 0 if delay_since_transaction < 0
          threshold = (Killbill::Plugin::ActiveMerchant::Utils.normalized(options, :cancel_threshold) || FIVE_MINUTES_AGO).to_i
          if delay_since_transaction >= threshold
            logger.info("Canceling UNDEFINED kb_transaction_id='#{transaction_info_plugin.kb_transaction_payment_id}'")
            response.cancel
            stale = true
          end
        end

        # If we updated the state, re-fetch the latest data
        stale ? super(kb_account_id, kb_payment_id, properties, context) : transaction_info_plugins
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
    end
  end
end
