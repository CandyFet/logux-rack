# frozen_string_literal: true

require 'spec_helper'

describe Logux::ActionController do
  let(:action_controller) do
    described_class.new(action: action, meta: meta, resending: resending)
  end
  let(:resending) do
    lambda do |targets|
      stream.write(['resend', meta.id, targets])
      stream.write(',')
    end
  end
  let(:stream) { Logux::Stream.new([]) }

  let(:action) { create(:logux_action_subscribe) }
  let(:meta) { Logux::Meta.new }

  describe '#respond' do
    subject(:response) { action_controller.respond(:processed) }

    it 'returns logux response' do
      expect(response).to have_attributes(
        status: :processed, action: action, custom_data: nil
      )
    end

    it 'sets the meta with time' do
      expect(response.meta).to have_key('time')
    end
  end

  describe '#send_back' do
    subject(:send_back) { action_controller.send_back(back_action, back_meta) }

    let(:back_action) { { 'type' => 'added' } }
    let(:back_meta) { { 'meta_key' => 'meta_value' } }

    let(:expected_commands) do
      [
        'action',
        back_action,
        a_logux_meta_with({ clients: [meta.client_id] }.merge(back_meta))
      ]
    end

    it 'makes request with correct clients' do
      expect { send_back }.to send_to_logux(expected_commands)
    end
  end

  describe '#resend' do
    subject(:resend) { action_controller.resend(targets) }

    let(:targets) { { 'channel' => 'users' } }

    before { resend }

    it 'writes to the stream resending message' do
      expect(
        JSON.parse(stream.stream.first)
      ).to eq(['resend', meta.id, targets])
    end

    it 'adds comma for further stream writing' do
      expect(stream.stream.last).to eq(',')
    end
  end

  describe '.verify_authorized!' do
    subject(:verify_authorized!) { described_class.verify_authorized! }

    around do |example|
      Logux.configuration.verify_authorized = false
      example.call
      Logux.configuration.verify_authorized = true
    end

    it 'sets to true' do
      expect { verify_authorized! }
        .to change { Logux.configuration.verify_authorized }
        .from(false)
        .to(true)
    end
  end

  describe '.unverify_authorized!' do
    subject(:unverify_authorized!) { described_class.unverify_authorized! }

    before { Logux.configuration.verify_authorized = true }

    it 'sets to false' do
      expect { unverify_authorized! }
        .to change { Logux.configuration.verify_authorized }
        .from(true)
        .to(false)
    end
  end
end
