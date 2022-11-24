# frozen_string_literal: true

RSpec.describe Identity::Serializer do
  let(:serializer) do
    described_class.new(
      name: ->(user) { user.name },
      email: ->(user) { user.email }
    )
  end

  let(:user) do
    Struct.new(:name, :email).new('John Doe', 'person@example.org')
  end

  context 'when dumping to a hash' do
    let(:dumped) { serializer.dump(user) }

    it 'dumps the user with the schema' do
      expect(dumped.except(:schema_version)).to eq(
        name: 'John Doe',
        email: 'person@example.org'
      )
    end
  end

  context 'when loading a hash' do
    it 'loads a hash with valid keys' do
      dumped = serializer.dump(user)

      expect(serializer.loadable_hash(dumped)).to eq(
        name: 'John Doe',
        email: 'person@example.org'
      )
    end

    it 'raises an error when the hash is missing a key' do
      dumped = serializer.dump(user)
      invalid = dumped.except(:name)

      expect { serializer.loadable_hash(invalid) }.to raise_error(
        Identity::SchemaMismatch,
        /expected {email, name}, got {email}/
      )
    end

    it 'raises an error when the hash has an extra key' do
      dumped = serializer.dump(user)
      invalid = dumped.merge(extra: 'value')

      expect { serializer.loadable_hash(invalid) }.to raise_error(
        Identity::SchemaMismatch,
        /expected {email, name}, got {email, extra, name}/
      )
    end
  end
end
