module Killbill #:nodoc:
  module Orbital #:nodoc:
    class PrivatePaymentPlugin < ::Killbill::Plugin::ActiveMerchant::PrivatePaymentPlugin
      def initialize(session = {})
        super(:orbital,
              ::Killbill::Orbital::OrbitalPaymentMethod,
              ::Killbill::Orbital::OrbitalTransaction,
              ::Killbill::Orbital::OrbitalResponse,
              session)
      end
    end
  end
end
