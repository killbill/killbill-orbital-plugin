module Killbill #:nodoc:
  module Orbital #:nodoc:
    class OrbitalPaymentMethod < ::Killbill::Plugin::ActiveMerchant::ActiveRecord::PaymentMethod

      self.table_name = 'orbital_payment_methods'

      def self.from_response(kb_account_id, kb_payment_method_id, kb_tenant_id, cc_or_token, response, options, extra_params = {}, model = ::Killbill::Orbital::OrbitalPaymentMethod)
        super(kb_account_id,
              kb_payment_method_id,
              kb_tenant_id,
              cc_or_token,
              response,
              options,
              {
                :cc_number => extract(response, 'cc_account_num'),
              }.merge!(extra_params),
              model)
      end
    end
  end
end
