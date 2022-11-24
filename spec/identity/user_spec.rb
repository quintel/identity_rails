# frozen_string_literal: true

RSpec.describe Identity::User do
  describe '.load' do
    context 'with valid data' do
      let(:user) do
        described_class.load(
          id: '123',
          roles: %w[admin],
          email: 'hello@example.org',
          name: 'John Doe'
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

      it 'sets the roles' do
        expect(user.roles).to eq(Set.new(%w[admin]))
      end
    end

    context 'when the e-mail is not a string' do
      it 'raises an error' do
        expect { described_class.load(id: '123', roles: %w[admin], email: 123, name: 'John Doe') }
          .to raise_error(Identity::Error, /123 violates constraints/)
      end
    end

    context 'when the e-mail is nil' do
      it 'sets no e-mail address' do
        user = described_class.load(id: '123', roles: %w[admin], email: nil, name: 'John Doe')
        expect(user.email).to be_nil
      end
    end

    context 'when the ID is nil' do
      it 'raises an error' do
        expect { described_class.load(id: nil, roles: %w[admin], email: '', name: '') }
          .to raise_error(Identity::Error, /nil violates constraints/)
      end
    end

    context 'when the ID is an integer' do
      it 'sets the ID as a string' do
        user = described_class.load(id: 123, roles: %w[admin], email: '', name: '')
        expect(user.id).to eq('123')
      end
    end

    context 'when a required key is not provided' do
      it 'raises an error' do
        expect { described_class.load(roles: %w[admin], email: 'hello@example.org', name: 'John') }
          .to raise_error(Identity::Error, /Schema version mismatch/)
      end
    end

    context 'with an extra value' do
      it 'raises a SchemaError' do
        expect do
          described_class.load(
            id: '123',
            roles: %w[admin],
            email: 'hello@example.org',
            name: 'John Doe',
            extra: 'value'
          )
        end.to raise_error(Identity::Error, /Schema version mismatch/)
      end
    end

    context 'with a missing value' do
      it 'raises a SchemaError' do
        expect do
          described_class.load(
            id: '123',
            roles: %w[admin],
            email: 'hello@example.org'
          )
        end.to raise_error(Identity::Error, /Schema version mismatch/)
      end
    end
  end

  describe '.from_omniauth_hash' do
    context 'with a valid hash' do
      let(:user) do
        described_class.from_omniauth_hash(
          'uid' => '123',
          'info' => {
            'email' => 'hello@example.org',
            'name' => 'John Doe',
            'roles' => %w[admin]
          }
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

      it 'sets the roles' do
        expect(user.roles).to eq(Set.new(%w[admin]))
      end
    end
  end

  describe '#dump' do
    let(:user) do
      described_class.new(
        id: '123',
        email: 'hello@example.org',
        name: 'John Doe',
        roles: %w[user admin]
      )
    end

    it 'includes all the values' do
      expect(user.dump).to eq(
        id: '123',
        email: 'hello@example.org',
        name: 'John Doe',
        roles: %w[user admin]
      )
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
end
