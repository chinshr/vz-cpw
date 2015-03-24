require 'pocketsphinx-ruby'

microphone = Pocketsphinx::Microphone.new

File.open("test.raw", "wb") do |file|
  microphone.record do
    FFI::MemoryPointer.new(:int16, 4096) do |buffer|
      50.times do
        sample_count = microphone.read_audio(buffer, 4096)
        file.write buffer.get_bytes(0, sample_count * 2)

        sleep 0.1
      end
    end
  end
end