module Killbill #:nodoc:
  module Orbital #:nodoc:
    class OrbitalTransaction < ::Killbill::Plugin::ActiveMerchant::ActiveRecord::Transaction

      self.table_name = 'orbital_transactions'

      belongs_to :orbital_response

    end
  end
end
