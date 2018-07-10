require 'bundler'
require 'orbital'
require 'killbill/helpers/active_merchant/killbill_spec_helper'

require 'logger'

require 'rspec'

RSpec.configure do |config|
  config.color_enabled = true
  config.tty = true
  config.formatter = 'documentation'
end

require 'active_record'
ActiveRecord::Base.establish_connection(
    :adapter => 'sqlite3',
    :database => 'test.db'
)
# For debugging
#ActiveRecord::Base.logger = Logger.new(STDOUT)
# Create the schema
require File.expand_path(File.dirname(__FILE__) + '../../db/schema.rb')

def create_payment
  kb_payment_id = SecureRandom.uuid
  1.upto(6) do
    @kb_payment = @plugin.kb_apis.proxied_services[:payment_api].add_payment(kb_payment_id)
  end
  [kb_payment_id, @kb_payment.transactions[0].id]
end

def merge_extra_properties(properties, extra_properties)
  new_properties = properties.clone
  extra_properties.each do |p|
    new_properties << p
  end
  new_properties
end

