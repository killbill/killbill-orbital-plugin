require 'spec_helper'

describe Killbill::Orbital::PaymentPlugin do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  before(:each) do
    Dir.mktmpdir do |dir|
      file = File.new(File.join(dir, 'orbital.yml'), 'w+')
      file.write(<<-eos)
:orbital:
  :test: true
# As defined by spec_helper.rb
:database:
  :adapter: 'sqlite3'
  :database: 'test.db'
      eos
      file.close

      @plugin = build_plugin(::Killbill::Orbital::PaymentPlugin, 'orbital', File.dirname(file))

      # Start the plugin here - since the config file will be deleted
      @plugin.start_plugin
    end
  end

  it 'should start and stop correctly' do
    @plugin.stop_plugin
  end

  it 'should reset undefined status to canceled' do
    response_message = {:exception_message => 'Timeout', :payment_plugin_status => :UNDEFINED}.to_json
    gw_response = ::ActiveMerchant::Billing::Response.new(false, response_message)
    response = Killbill::Orbital::OrbitalResponse.from_response('authorization',
                                                                SecureRandom.uuid,
                                                                SecureRandom.uuid,
                                                                SecureRandom.uuid,
                                                                'authorize',
                                                                'test',
                                                                SecureRandom.uuid,
                                                                gw_response,
                                                                {})
    plugin_info = response.to_transaction_info_plugin
    plugin_info.status.should == :CANCELED
  end
end
