require 'spec_helper'

ActiveMerchant::Billing::Base.mode = :test

shared_examples 'common_specs' do
  before(:each) do
    create_payment
  end

  after(:each) do
    @plugin.stop_plugin
  end

  it 'should be able to purchase' do
    Killbill::Orbital::OrbitalResponse.all.size.should == 1
    Killbill::Orbital::OrbitalTransaction.all.size.should == 0

    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE

    responses = Killbill::Orbital::OrbitalResponse.all
    responses.size.should == 2
    responses[0].api_call.should == 'add_payment_method'
    responses[0].message.should == 'Profile Request Processed'
    responses[1].api_call.should == 'purchase'
    responses[1].message.should == 'Approved'
    transactions = Killbill::Orbital::OrbitalTransaction.all
    transactions.size.should == 1
    transactions[0].api_call.should == 'purchase'
  end

  it 'should be able to charge and refund' do
    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE

    # Try a full refund
    refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    refund_response.status.should eq(:PROCESSED), refund_response.gateway_error
    refund_response.amount.should == @amount
    refund_response.transaction_type.should == :REFUND
  end

  it 'should be able to auth, capture and refund' do
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE

    # Try multiple partial captures
    partial_capture_amount = BigDecimal.new('10')
    1.upto(3) do |i|
      payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[i].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
      payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
      payment_response.amount.should == partial_capture_amount
      payment_response.transaction_type.should == :CAPTURE
    end

    # Try a partial refund
    refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[4].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    refund_response.status.should eq(:PROCESSED), refund_response.gateway_error
    refund_response.amount.should == partial_capture_amount
    refund_response.transaction_type.should == :REFUND

    # Try to capture again
    payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[5].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == partial_capture_amount
    payment_response.transaction_type.should == :CAPTURE
  end

  it 'should be able to auth and void' do
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE

    payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.transaction_type.should == :VOID
  end

  it 'should be able to auth, partial capture and void' do
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE

    partial_capture_amount = BigDecimal.new('10')
    payment_response       = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == partial_capture_amount
    payment_response.transaction_type.should == :CAPTURE

    payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[2].id, @pm.kb_payment_method_id, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.transaction_type.should == :VOID
  end
end

shared_examples 'cvv_indicator_specs' do
  after(:each) do
    @plugin.stop_plugin
  end

  it 'should set correct indicator for visa and discover if cvv value is present regardless of cvv_indicator_visa_discover' do
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


describe Killbill::Orbital::PaymentPlugin do

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

  context 'credit card flow' do
    before(:each) do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454' })
      @pm         = create_payment_method(::Killbill::Orbital::OrbitalPaymentMethod, nil, @call_context.tenant_id, @properties, {})
      @amount     = BigDecimal.new('100')
      @currency   = 'USD'
    end

    include_examples 'common_specs'
  end

  context 'custom profile flow' do
    before(:each) do
      @properties = []
      @pm         = create_payment_method(::Killbill::Orbital::OrbitalPaymentMethod, nil, @call_context.tenant_id, @properties, { :cc_number => '5454545454545454' })
      @amount     = BigDecimal.new('100')
      @currency   = 'USD'
    end

    include_examples 'common_specs'
  end

  context 'cvv indicator spec' do
    before(:each) do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454' })
      @pm         = create_payment_method(::Killbill::Orbital::OrbitalPaymentMethod, nil, @call_context.tenant_id, @properties, {})
      @amount     = BigDecimal.new('100')
      @currency   = 'USD'
    end

    include_examples 'cvv_indicator_specs'
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
    create_payment
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE

    create_payment
    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE
  end

  def create_payment
    kb_payment_id = SecureRandom.uuid
    1.upto(6) do
      @kb_payment = @plugin.kb_apis.proxied_services[:payment_api].add_payment(kb_payment_id)
    end
    kb_payment_id
  end
end
