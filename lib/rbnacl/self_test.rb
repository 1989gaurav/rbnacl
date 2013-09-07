start = Time.now if $DEBUG

module RbNaCl
  class SelfTestFailure < RbNaCl::CryptoError; end

  module SelfTest
    module_function

    def vector(name)
      [TestVectors[name]].pack("H*")
    end

    def box_test
      alicepk = RbNaCl::PublicKey.new(vector(:alice_public))
      bobsk = RbNaCl::PrivateKey.new(vector(:bob_private))

      box = RbNaCl::Box.new(alicepk, bobsk)
      box_common_test(box)
    end

    def secret_box_test
      box = SecretBox.new(vector(:secret_key))
      box_common_test(box)
    end

    def box_common_test(box)
      nonce      = vector :box_nonce
      message    = vector :box_message
      ciphertext = vector :box_ciphertext

      unless box.encrypt(nonce, message) == ciphertext
        raise SelfTestFailure, "failed to generate correct ciphertext"
      end

      unless box.decrypt(nonce, ciphertext) == message
        raise SelfTestFailure, "failed to decrypt ciphertext correctly"
      end

      begin
        passed         = false
        corrupt_ct     = ciphertext.dup
        corrupt_ct[23] = ' '
        box.decrypt(nonce, corrupt_ct)
      rescue CryptoError
        passed = true
      ensure
        passed or raise SelfTestFailure, "failed to detect corrupt ciphertext"
      end
    end

    def digital_signature_test
      signing_key = SigningKey.new(vector(:sign_private))
      verify_key  = signing_key.verify_key

      unless verify_key.to_s == vector(:sign_public)
        raise SelfTestFailure, "failed to generate verify key correctly"
      end

      message   = vector :sign_message
      signature = signing_key.sign(message)

      unless signature == vector(:sign_signature)
        raise SelfTestFailure, "failed to generate correct signature"
      end

      unless verify_key.verify(message, signature)
        raise SelfTestFailure, "failed to verify a valid signature"
      end

      bad_signature = signature[0,63] + '0'

      unless verify_key.verify(message, bad_signature) == false
        raise SelfTestFailure, "failed to detect an invalid signature"
      end
    end

    def sha256_test
      message = vector :sha256_message
      digest  = vector :sha256_digest

      unless RbNaCl::Hash.sha256(message) == digest
        raise SelfTestFailure, "failed to generate a correct SHA256 digest"
      end
    end

    def hmac_test(klass, tag)
      authenticator = klass.new(vector(:auth_key))

      message = vector :auth_message

      unless authenticator.auth(message) == vector(tag)
        raise SelfTestFailure, "#{klass} failed to generate correct authentication tag"
      end

      unless authenticator.verify(message, vector(tag))
        raise SelfTestFailure, "#{klass} failed to verify correct authentication tag"
      end

      if authenticator.verify(message+' ', vector(tag))
        raise SelfTestFailure, "#{klass} failed to detect invalid authentication tag"
      end
    end
  end
end

RbNaCl::SelfTest.box_test
RbNaCl::SelfTest.secret_box_test
RbNaCl::SelfTest.digital_signature_test
RbNaCl::SelfTest.sha256_test
RbNaCl::SelfTest.hmac_test RbNaCl::HMAC::SHA256,    :auth_hmacsha256
RbNaCl::SelfTest.hmac_test RbNaCl::HMAC::SHA512256, :auth_hmacsha512256
RbNaCl::SelfTest.hmac_test RbNaCl::Auth::OneTime,   :auth_onetime

puts "POST Completed in #{Time.now - start} s" if $DEBUG
