shared_examples 'visa_mit_cit_framework_spec' do

  before(:each) do
    create_payment
  end

  after(:each) do
    @plugin.stop_plugin
  end

  it 'should be able to persist and query mit transaction id' do
    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'CGEN'),
                                                      build_property('credential_on_file', true)])
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'
    mit_trx_id = find_value_from_properties(payment_response.properties, 'mit_received_transaction_id')
    mit_trx_id.should_not be_nil

    mit_received_transaction_id = @plugin.send('find_mit_ref_trx_id_if_needed', @kb_payment.transactions[0].id, @call_context.tenant_id)
    mit_received_transaction_id.should == mit_trx_id
  end

  it 'should be able to do authorization with a matching mit_transaction_id and send the correct reference mit transaction id' do
    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'CGEN'),
                                                      build_property('credential_on_file', true)])
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    mit_trx_id = find_value_from_properties(payment_response.properties, 'mit_received_transaction_id')

    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'MRSB'),
                                                      build_property('credential_on_file', true),
                                                      build_property('mit_ref_trx_id', @kb_payment.transactions[0].id)])

    ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do |host, request_body|
      request_body.should match("<MITSubmittedTransactionID>#{mit_trx_id}</MITSubmittedTransactionID>")
      request_body.should match("<MITMsgType>MRSU</MITMsgType>")
    end
    @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
  end

  it 'should be able to do successful authorization with mit ref id' do
    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'CGEN'),
                                                      build_property('credential_on_file', true)])
    @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)

    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'MRSB'),
                                                      build_property('credential_on_file', true),
                                                      build_property('mit_ref_trx_id', @kb_payment.transactions[0].id)])
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    payment_response.status.should ==:PROCESSED
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'
  end

  it 'should not able to do successful authorization with non-matching mit ref id' do
    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'CGEN'),
                                                      build_property('credential_on_file', true)])
    @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)

    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'MRSB'),
                                                      build_property('credential_on_file', true),
                                                      build_property('mit_ref_trx_id', 'test_id')])
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    payment_response.status.should == :ERROR
    payment_response.gateway_error.should ==' MIT: Original transaction id is mandatory for merchant initiated transactions.'
  end

  it 'should be able to do successful purchase with mit ref id' do
    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'CGEN'),
                                                      build_property('credential_on_file', true)])
    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    mit_trx_id = find_value_from_properties(payment_response.properties, 'mit_received_transaction_id')
    mit_trx_id.should_not be_nil

    properties = merge_extra_properties(@properties, [build_property('mit_cit_type', 'MRSB'),
                                                      build_property('credential_on_file', true),
                                                      build_property('mit_ref_trx_id', @kb_payment.transactions[0].id)])
    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'
  end

  def merge_extra_properties(properties, extra_properties)
    new_properties = properties.clone
    extra_properties.each do |p|
      new_properties << p
    end
    new_properties
  end

end