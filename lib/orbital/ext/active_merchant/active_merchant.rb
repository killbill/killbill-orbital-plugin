module ActiveMerchant
  module Billing
    class OrbitalGateway

      def store(creditcard, options = {})
        add_customer_profile(creditcard, options)
      end
    end
  end
end
