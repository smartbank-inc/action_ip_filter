# action_ip_filter

A lightweight gem that provides IP address restrictions for Rails controllers at the action level.

## Why action_ip_filter?

Unlike Rack middleware solutions (e.g., `rack-attack`), action_ip_filter operates at the controller level:

| Feature | rack-attack | action_ip_filter |
|---------|-------------|----------------|
| Layer | Rack middleware (all requests) | Controller before_action |
| Granularity | Path/IP based | Controller/Action based |
| Overhead | Every request evaluated | Only specified actions |
| Use case | DDoS protection, rate limiting | Admin panels, webhooks |

**Use this gem when you need:**
- IP restrictions on specific controller actions only
- Minimal overhead (no processing for unrestricted endpoints)
- Simple, declarative configuration per controller

## Installation

Add to your Gemfile:

```ruby
gem "action_ip_filter"
```

Then run:

```bash
bundle install
```

## Usage

### Basic Usage

Include the concern and use `restrict_ip` to protect specific actions:

```ruby
class AdminController < ApplicationController
  include ActionIpFilter::IpFilterable

  restrict_ip :index, :show, allowed_ips: %w[192.0.2.0/24 198.51.100.1]

  def index
    # Only accessible from 192.0.2.0/24 or 198.51.100.1
  end

  def show
    # Also restricted
  end

  def public_action
    # Not restricted
  end
end
```

### Restrict All Actions

Use `restrict_ip_for_all` to protect all actions with optional exceptions:

```ruby
class WebhooksController < ApplicationController
  include ActionIpFilter::IpFilterable

  restrict_ip_for_all allowed_ips: ENV["WEBHOOK_ALLOWED_IPS"].to_s.split(","),
                      except: [:health_check]

  def stripe
    # Restricted
  end

  def health_check
    # Not restricted
  end
end
```

### Dynamic IP Lists

Pass a Proc for dynamic IP resolution:

```ruby
class SecureController < ApplicationController
  include ActionIpFilter::IpFilterable

  restrict_ip :sensitive_action,
    allowed_ips: -> { Rails.application.credentials.dig(:allowed_ips) || [] }
end
```

### Custom Denial Handler

Customize the response when access is denied. The block is executed via `instance_exec` in the controller context, so you can use controller methods like `head`, `render`, etc. The request object is passed as an argument:

```ruby
class ApiController < ApplicationController
  include ActionIpFilter::IpFilterable

  restrict_ip :create,
    allowed_ips: %w[192.0.2.0/24],
    on_denied: ->(request) { render json: { error: "Access denied from #{request.remote_ip}" }, status: :forbidden }
end
```

## Configuration

Configure global settings in an initializer:

```ruby
# config/initializers/action_ip_filter.rb
ActionIpFilter.configure do |config|
  # Custom IP resolver (default: request.remote_ip)
  config.ip_resolver = ->(request) {
    request.headers["X-Forwarded-For"]&.split(",")&.first&.strip || request.remote_ip
  }

  # Default denial handler (receives request, executed via instance_exec in controller)
  config.on_denied = ->(request) { head :forbidden }

  # Logger for denied requests
  config.logger = Rails.logger

  # Enable/disable denial logging (default: true)
  config.log_denials = true
end
```

### Default Values

| Option | Default                             | Description                                        |
|--------|-------------------------------------|----------------------------------------------------|
| `ip_resolver` | `->(request) { request.remote_ip }` | Proc that extracts client IP from request |
| `on_denied` | `-> { head :forbidden }`            | Handler called when access is denied (returns 403) |
| `logger` | `Rails.logger`                      | Logger instance for denied request logging |
| `log_denials` | `true`                              | Whether to log denied requests as warn level |

## Testing

### Bypass IP Filter in Tests

Use the test helpers to bypass IP restrictions:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include ActionIpFilter::TestHelpers

  # Option 1: Globally bypass in all tests
  config.before do
    ActionIpFilter.test_mode = true
  end
end
```

Or use helpers for specific tests:

```ruby
RSpec.describe "Admin", type: :request do
  include ActionIpFilter::TestHelpers

  describe "GET /admin" do
    it "allows access when filter is bypassed" do
      without_ip_filter do
        get "/admin"
        expect(response).to have_http_status(:ok)
      end
    end

    it "denies access from unauthorized IP" do
      with_ip_filter do
        get "/admin"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
```

## Supported IP Formats

- Single IPv4: `192.0.2.1`
- Single IPv6: `::1`, `2001:db8::1`
- CIDR notation: `192.0.2.0/24`
- IPv6 CIDR: `2001:db8::/32`

## Logging

When `log_denials` is enabled (default), denied requests are logged:

```
[ActionIpFilter] Access denied for IP: 192.0.2.1 on MyController#index
```

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run type checker
bundle exec rake rbs

# Run linter
bundle exec standardrb
```

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
