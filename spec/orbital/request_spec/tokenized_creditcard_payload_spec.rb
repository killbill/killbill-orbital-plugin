require 'spec_helper'

ActiveMerchant::Billing::Base.mode = :test

describe 'Payment request for network tokenized card' do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  before(:each) do
    # Start the plugin early to configure ActiveRecord
    @plugin = build_plugin(::Killbill::Orbital::PaymentPlugin, 'orbital')
    @plugin.start_plugin

    ::Killbill::Orbital::OrbitalPaymentMethod.delete_all
    ::Killbill::Orbital::OrbitalResponse.delete_all
    ::Killbill::Orbital::OrbitalTransaction.delete_all

    @call_context = build_call_context
  end

  after(:each) do
    @plugin.stop_plugin
  end

  it 'should send correct payload for visa network tokenized card' do

    cryptogram  = 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    @properties = build_pm_properties(nil,
                                     {
                                         :cc_number => 4111111111111111,
                                         :cc_type => 'visa',
                                         :payment_cryptogram => cryptogram
                                     })
    @pm         = create_payment_method(::Killbill::Orbital::OrbitalPaymentMethod, nil, @call_context.tenant_id, @properties, {})
    @amount     = BigDecimal.new('100')
    @currency   = 'USD'

    ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do |host, request_body|
      request_body.should match("<CAVV>#{cryptogram}</CAVV>")
      request_body.should match('<DPANInd>Y</DPANInd>')
      request_body.should match("<DigitalTokenCryptogram>#{cryptogram}</DigitalTokenCryptogram>")

      successful_authorize_response
    end

    validate_payment
  end

  it 'should send correct payload for amex network tokenized card' do

    cryptogram  = 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    @properties = build_pm_properties(nil,
                                     {
                                         :cc_number => 378282246310005,
                                         :cc_type => 'american_express',
                                         :payment_cryptogram => cryptogram,
                                         :eci => '7'
                                     })
    @pm         = create_payment_method(::Killbill::Orbital::OrbitalPaymentMethod, nil, @call_context.tenant_id, @properties, {})
    @amount     = BigDecimal.new('100')
    @currency   = 'USD'

    ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do |host, request_body|
      request_body.should match("<AEVV>#{cryptogram}</AEVV>")
      request_body.should match('<DPANInd>Y</DPANInd>')
      request_body.should match("<DigitalTokenCryptogram>#{cryptogram}</DigitalTokenCryptogram>")
      request_body.should match('<AuthenticationECIInd>7</AuthenticationECIInd>')

      successful_authorize_response
    end

    validate_payment
  end

  it 'should send correct payload for master network tokenized card' do

    cryptogram  = 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    @properties = build_pm_properties(nil,
                                     {
                                         :cc_number => 5555555555554444,
                                         :cc_type => 'master',
                                         :payment_cryptogram => cryptogram
                                     })
    @pm         = create_payment_method(::Killbill::Orbital::OrbitalPaymentMethod, nil, @call_context.tenant_id, @properties, {})
    @amount     = BigDecimal.new('100')
    @currency   = 'USD'

    ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do |host, request_body|
      request_body.should match("<AAV>#{cryptogram}</AAV>")
      request_body.should match('<DPANInd>Y</DPANInd>')
      request_body.should match("<DigitalTokenCryptogram>#{cryptogram}</DigitalTokenCryptogram>")

      successful_authorize_response
    end

    validate_payment
  end

  it 'should send correct payload for discover network tokenized card' do

    cryptogram  = 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    @properties = build_pm_properties(nil,
                                     {
                                         :cc_number => 6011111111111117,
                                         :cc_type => 'discover',
                                         :payment_cryptogram => cryptogram
                                     })
    @pm         = create_payment_method(::Killbill::Orbital::OrbitalPaymentMethod, nil, @call_context.tenant_id, @properties, {})
    @amount     = BigDecimal.new('100')
    @currency   = 'USD'

    ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do |host, request_body|
      request_body.should match('<DPANInd>Y</DPANInd>')
      request_body.should match("<DigitalTokenCryptogram>#{cryptogram}</DigitalTokenCryptogram>")

      successful_authorize_response
    end

    validate_payment
  end

  private

  def successful_authorize_response
    <<-XML
<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>A</MessageType><MerchantID>1111111</MerchantID><TerminalID>001</TerminalID><CardBrand>CC</CardBrand><AccountNum>XXXXXXXXXXXX5454</AccountNum><OrderID>5b257b31-1f84-44bc-b32</OrderID><TxRefNum>5834AA75E4466AEA59512165057C37DD810053C2</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>B </AVSRespCode><CVV2RespCode> </CVV2RespCode><AuthCode>tst424</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>I3</HostAVSRespCode><HostCVV2RespCode>  </HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>152837</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>
    XML
  end

  def validate_payment
    create_payment
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
  end

end