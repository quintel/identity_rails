# frozen_string_literal: true

RSpec.describe Identity::ControllerHelpers do
  context 'when the serialized session is invalid' do
    let(:controller) do
      Class.new do
        def self.helper_method(*); end

        include Identity::ControllerHelpers

        def identity_session_attributes
          { 'invalid' => true }
        end

        def reset_session; end
      end.new
    end

    it 'resets the session' do
      allow(controller).to receive(:reset_session)

      controller.send(:identity_session)
      expect(controller).to have_received(:reset_session)
    end
  end

  context 'when the refreshing the token fails' do
    let(:controller) do
      Class.new do
        def self.helper_method(*); end

        include Identity::ControllerHelpers

        def identity_session_attributes
          { 'invalid' => true }
        end

        def reset_session; end
      end.new
    end

    before do
      allow(Identity::Session).to receive(:load_fresh).and_raise(Identity::InvalidGrant)
    end

    it 'resets the session' do
      allow(controller).to receive(:reset_session)

      controller.send(:identity_session)
      expect(controller).to have_received(:reset_session)
    end
  end

  context 'when an unexpected error occurs' do
    let(:controller) do
      Class.new do
        def self.helper_method(*); end

        include Identity::ControllerHelpers

        def identity_session_attributes
          { 'invalid' => true }
        end

        def reset_session; end
      end.new
    end

    before do
      allow(Identity::Session).to receive(:load_fresh).and_raise(Identity::Error, 'oops')
    end

    it 'resets the session' do
      allow(controller).to receive(:reset_session)

      begin
        controller.send(:identity_session)
      rescue Identity::Error
        # Do nothing.
      end

      expect(controller).to have_received(:reset_session)
    end

    it 'raises the error' do
      expect { controller.send(:identity_session) }.to raise_error(Identity::Error, 'oops')
    end
  end
end
