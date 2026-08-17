class ApplicationJob < ActiveJob::Base
  if defined?(OpenAI::Errors::RateLimitError)
    retry_on OpenAI::Errors::RateLimitError, wait: :polynomially_longer, attempts: 5
  elsif defined?(Faraday::TooManyRequestsError)
    retry_on Faraday::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  end
  retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
end
