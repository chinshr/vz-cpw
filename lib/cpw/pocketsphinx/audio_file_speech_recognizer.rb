module CPW
  module Pocketsphinx
    class AudioFileSpeechRecognizer < ::Pocketsphinx::AudioFileSpeechRecognizer

      private

      # Override from superclass
      def recognize_after_speech(max_samples, buffer)
        if in_speech?
          while in_speech?
            process_audio(buffer, max_samples) or break
          end

          decoder.end_utterance
          hypothesis = decoder.hypothesis

          yield decoder # if decoder.hypothesis
          decoder.start_utterance
        end

        process_audio(buffer, max_samples)
      end

    end
  end
end