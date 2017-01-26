require 'spec_helper'

ActiveMerchant::Billing::Base.mode = :test

describe Killbill::Orbital::PaymentPlugin do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  before(:each) do
    @plugin = build_plugin(::Killbill::Orbital::PaymentPlugin, 'orbital')
    @plugin.start_plugin
    @call_context = build_call_context

    ::Killbill::Orbital::OrbitalPaymentMethod.delete_all
    ::Killbill::Orbital::OrbitalResponse.delete_all
    ::Killbill::Orbital::OrbitalTransaction.delete_all
  end

  after(:each) do
    @plugin.stop_plugin
  end

  context 'cvv indicator spec' do
    before(:each) do
      @amount     = BigDecimal.new('100')
      @currency   = 'USD'
    end

    it 'should set correct indicator for visa and discover if cvv value is present regardless of cvv_indicator_visa_discover' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454' })
      validate_cvv_indicator_field 1

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'discover' })
      validate_cvv_indicator_field 1

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cvv_indicator_visa_discover => true })
      validate_cvv_indicator_field 1

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'discover', :cvv_indicator_visa_discover => true  })
      validate_cvv_indicator_field 1
    end

    it 'should set correct indicator for visa and discover if cvv value is not present and cvv_indicator_visa_discover is true' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cvv_indicator_visa_discover => true })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field 9

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'discover', :cvv_indicator_visa_discover => true })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field 9
    end

    it 'should set customized indicator for visa and discover if cvv value is not present and cvv_indicator_visa_discover is true and cvv_indicator_override_visa_discover is given' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cvv_indicator_visa_discover => true, :cvv_indicator_override_visa_discover => '2' })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field 2

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'discover', :cvv_indicator_visa_discover => true, :cvv_indicator_override_visa_discover => '2' })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field 2
    end

    it 'should set correct indicator for visa and discover if cvv value is not present and cvv_indicator_visa_discover is nil or false' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454'})
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'discover'})
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cvv_indicator_visa_discover => false })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'discover', :cvv_indicator_visa_discover => false })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field
    end

    it 'should not include indicator except visa and discover for all cases' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master' })
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'american_express' })
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master', :cvv_indicator_visa_discover => false })
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'american_express', :cvv_indicator_visa_discover => false })
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master', :cvv_indicator_visa_discover => true})
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'american_express', :cvv_indicator_visa_discover => true })
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master' })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'american_express' })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master', :cvv_indicator_visa_discover => false})
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'american_express', :cvv_indicator_visa_discover => false })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master', :cvv_indicator_visa_discover => true})
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field

      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'american_express', :cvv_indicator_visa_discover => true })
      @properties.reject! {|property| property.key == 'ccVerificationValue' }
      validate_cvv_indicator_field
    end
  end

  def successful_authorize_response
    <<-XML
<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>A</MessageType><MerchantID>1111111</MerchantID><TerminalID>001</TerminalID><CardBrand>CC</CardBrand><AccountNum>XXXXXXXXXXXX5454</AccountNum><OrderID>5b257b31-1f84-44bc-b32</OrderID><TxRefNum>5834AA75E4466AEA59512165057C37DD810053C2</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>B </AVSRespCode><CVV2RespCode> </CVV2RespCode><AuthCode>tst424</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>I3</HostAVSRespCode><HostCVV2RespCode>  </HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>152837</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>
    XML
  end

  def successful_purchase_response
    <<-XML
<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>1111111</MerchantID><TerminalID>001</TerminalID><CardBrand>CC</CardBrand><AccountNum>XXXXXXXXXXXX5454</AccountNum><OrderID>88132d30-f4f7-4028-949</OrderID><TxRefNum>5834EAC9C7A53FEB600A479629FB6C6427A2532C</TxRefNum><TxRefIdx>1</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>3 </AVSRespCode><CVV2RespCode>I</CVV2RespCode><AuthCode>tst703</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>  </HostAVSRespCode><HostCVV2RespCode>I</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>200306</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>    XML
    XML
  end

  def validate_cvv_indicator_field(expected_field = nil)
    ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do |host, request_body|
      if expected_field.nil?
        request_body.should_not match('<CardSecValInd>')
      else
        request_body.should match("<CardSecValInd>#{expected_field}</CardSecValInd>")
      end
      if request_body.include? '<MessageType>A</MessageType>'
        successful_authorize_response
      else
        successful_purchase_response
      end
    end

    authorize
    purchase
  end

  def authorize
    kb_payment_id, kb_transaction_id = create_payment
    payment_response = @plugin.authorize_payment(SecureRandom.uuid, kb_payment_id, kb_transaction_id, SecureRandom.uuid, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
  end

  def purchase
    kb_payment_id, kb_transaction_id = create_payment
    payment_response = @plugin.purchase_payment(SecureRandom.uuid, kb_payment_id, kb_transaction_id, SecureRandom.uuid, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE
  end
end