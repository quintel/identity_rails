# frozen_string_literal: true

RSpec.describe Identity::User do
  describe '.from_jwt_claims' do
    context 'with a valid claims hash' do
      let(:user) do
        described_class.from_jwt_claims(
          'sub' => '123',
          'user' => { 'email' => 'hello@example.org', 'name' => 'John Doe', 'admin' => true }
        )
      end

      it 'sets the ID' do
        expect(user.id).to eq('123')
      end

      it 'sets the e-mail' do
        expect(user.email).to eq('hello@example.org')
      end

      it 'sets the name' do
        expect(user.name).to eq('John Doe')
      end

      it 'derives the roles from the admin flag' do
        expect(user.roles).to eq(Set.new(%w[user admin]))
      end
    end

    context 'without an admin flag' do
      let(:user) do
        described_class.from_jwt_claims('sub' => '123', 'user' => { 'admin' => false })
      end

      it 'has the user role only' do
        expect(user.roles).to eq(Set.new(%w[user]))
      end

      it 'is not an admin' do
        expect(user).not_to be_admin
      end
    end

    context 'with a top-level roles claim' do
      let(:user) do
        described_class.from_jwt_claims(
          'sub' => '123', 'roles' => %w[user admin], 'user' => { 'admin' => false }
        )
      end

      # Guards against a provider that starts emitting a roles claim: privileges must come from the
      # signed `user.admin` flag every consumer agrees on, not from a claim nothing mints today.
      it 'ignores it in favour of the admin flag' do
        expect(user.roles).to eq(Set.new(%w[user]))
      end
    end

    context 'when the ID is nil' do
      it 'raises an error' do
        expect { described_class.from_jwt_claims('sub' => nil, 'user' => {}) }
          .to raise_error(Identity::Error, /nil violates constraints/)
      end
    end

    context 'when the ID is an integer' do
      it 'sets the ID as a string' do
        user = described_class.from_jwt_claims('sub' => 123, 'user' => {})
        expect(user.id).to eq('123')
      end
    end
  end

  describe '#admin?' do
    context 'when the user roles include "admin"' do
      let(:user) { described_class.new(id: 0, roles: %w[user admin], email: '', name: '') }

      it 'returns true' do
        expect(user).to be_admin
      end
    end

    context 'when the user roles do not include "admin"' do
      let(:user) { described_class.new(id: 0, roles: %w[user], email: '', name: '') }

      it 'returns false' do
        expect(user).not_to be_admin
      end
    end
  end

  describe '#==' do
    let(:user) { described_class.new(id: 1, roles: %w[user], email: '', name: 'John Doe') }

    it 'returns true when the IDs are the same' do
      expect(user).to eq(described_class.new(id: 1, roles: %w[user], email: '', name: 'John Doe'))
    end

    it 'returns true when the IDs are the same and other attributes differ' do
      expect(user).to eq(described_class.new(id: 1, roles: %w[user], email: '', name: ''))
    end

    it 'returns false when the IDs are different' do
      expect(user).not_to eq(
        described_class.new(id: 2, roles: %w[user], email: '', name: 'John Doe')
      )
    end

    it 'returns false when the other object is not a user' do
      expect(user).not_to eq(Object.new)
    end

    it 'returns false when the other object is nil' do
      expect(user).not_to eq(nil)
    end
  end
end
