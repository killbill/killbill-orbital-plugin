require 'spec_helper'

include ::Killbill::Plugin::ActiveMerchant::RSpec

ActiveMerchant::Billing::Base.mode = :test

shared_examples "avs_response_code_specs" do |raw_code, expected_code|
  it 'should translate to correct AVS codes from Orbital AVS codes' do
      ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do
        mock_authorize_response(raw_code)
      end
      validate_avs_response expected_code
  end

  def mock_authorize_response(code)
    <<-XML
<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>A</MessageType><MerchantID>1111111</MerchantID><TerminalID>001</TerminalID><CardBrand>CC</CardBrand><AccountNum>XXXXXXXXXXXX5454</AccountNum><OrderID>5b257b31-1f84-44bc-b32</OrderID><TxRefNum>5834AA75E4466AEA59512165057C37DD810053C2</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>#{code}</AVSRespCode><CVV2RespCode> </CVV2RespCode><AuthCode>tst424</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>I3</HostAVSRespCode><HostCVV2RespCode>  </HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>152837</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>
    XML
  end

  def validate_avs_response(expected_code)
    kb_payment_id, kb_transaction_id = create_payment
    payment_response = @plugin.authorize_payment(SecureRandom.uuid, kb_payment_id, kb_transaction_id, SecureRandom.uuid, @amount, @currency, @properties, @call_context)
    find_value_from_properties(payment_response.properties, 'avsResultCode').should == expected_code
  end
end

describe 'Should present correct AVS codes' do

  before(:each) do
    # Start the plugin early to configure ActiveRecord
    @plugin = build_plugin(::Killbill::Orbital::PaymentPlugin, 'orbital')
    @plugin.start_plugin
    ::Killbill::Orbital::OrbitalPaymentMethod.delete_all
    ::Killbill::Orbital::OrbitalResponse.delete_all
    ::Killbill::Orbital::OrbitalTransaction.delete_all
    @call_context = build_call_context
    @properties = build_pm_properties(nil,
                                      {
                                          :cc_number => 4111111111111111,
                                          :cc_type => 'visa'
                                      })
    @amount     = BigDecimal.new('100')
    @currency   = 'USD'
  end

  after(:each) do
    @plugin.stop_plugin
  end

  ::ActiveMerchant::Billing::OrbitalGateway::AVSResult::CONVERT_MAP.each do |raw_code, expected_code|
    include_examples "avs_response_code_specs", raw_code, expected_code
  end
end