require 'spec_helper'

describe Killbill::Orbital::OrbitalResponse do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  describe '.search_where_clause' do
    let(:arel_table) { described_class.arel_table }
    let(:search_key) { 'search_key' }

    subject { described_class.search_where_clause(arel_table, search_key).to_sql }

    before(:each) do
      Dir.mktmpdir do |dir|
        file = File.new(File.join(dir, 'orbital.yml'), 'w+')
        file.write(configs)
        file.close
  
        @plugin = build_plugin(::Killbill::Orbital::PaymentPlugin, 'orbital', File.dirname(file))

        # Start the plugin here - since the config file will be deleted
        @plugin.start_plugin
      end
    end

    after(:each) do
      @plugin.stop_plugin
    end

    context 'while search_fields is not configured' do
      let(:configs) {
        <<-eos
:orbital:
  :test: true
# As defined by spec_helper.rb
:database:
  :adapter: 'sqlite3'
  :database: 'test.db'
        eos
      }

      it 'should return the same where clause as ::Killbill::Plugin::ActiveMerchant::ActiveRecord::Response' do
        expected_search_where_clause = 
          ::Killbill::Plugin::ActiveMerchant::ActiveRecord::Response.search_where_clause(arel_table, search_key).to_sql
  
        expect(subject).to eq(expected_search_where_clause)
      end
    end

    context 'while search_fields is configured' do
      let(:configs) {
        <<-eos
:orbital:
  :test: true
# As defined by spec_helper.rb
:database:
  :adapter: 'sqlite3'
  :database: 'test.db'
:search_fields:
  - :params_tx_ref_num
        eos
      }

      it 'should return the where clause using the search_fields' do
        expect(subject).to eq("\"orbital_responses\".\"params_tx_ref_num\" = 'search_key'")
      end
    end
  end

  describe '.max_nb_records' do
    before(:each) do
      described_class.stub_chain(:succeeded, :limit, :offset, :nil?).and_return(target_response_nil?)
    end

    subject { described_class.max_nb_records }

    context 'when the target response exists' do
      let(:target_response_nil?) { false }

      it { should eq(described_class::SIMPLE_PAGINATION_THRESHOLD + 1) }
    end

    context 'when the target response does not exist' do
      let(:target_response_nil?) { true }
      let(:success_response_count) { 123 }

      before(:all) do
        described_class.stub_chain(:succeeded, :count).and_return(success_response_count)
      end

      it { should eq(success_response_count) }
    end
  end
end
