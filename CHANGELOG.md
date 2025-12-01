## [Unreleased]

## [0.4.0] - 2025-12-01

### Breaking Changes

#### Change both the behavior and the interface of `filter_ip` [#5](https://github.com/smartbank-inc/action_ip_filter/pull/5)

Previously, `filter_ip` accepted a variable number of action names along with an `allowed_ips:` parameter. It now instead accepts a variable number of allowed IP addresses.

When neither `only:` nor `except:` is specified, the filter is applied to all actions in the controller. To restric filtering to specific actions, `only:` or `except:` must be used—similar to how `before_action` is scoped.

**Example:**

Before:

```ruby
filter_ip :index, :show, allowed_ips: %w[192.0.2.0/24 198.51.100.1]
```

After:

```ruby
filter_ip "192.0.2.0/24", "198.51.100.1", only: [:index, :show]
```

## [0.3.1] - 2025-12-01

- Simplify IpMatcher#match? by removing unnecessary branching [#3](https://github.com/smartbank-inc/action_ip_filter/pull/3)

## [0.3.0] - 2025-11-29

### Breaking Changes

#### Change `ip_resolver` to use controller context instead of request parameter [#1](https://github.com/smartbank-inc/action_ip_filter/pull/1)

Usage has changed. The `request` parameter in the Proc was previously required, but it is no longer needed. You can now access controller methods (`request`, `params`, etc.) directly instead of receiving `request` as an argument.

Before:

```
config.ip_resolver = ->(request) {
  request.headers["X-Forwarded-For"]&.split(",")&.first&.strip || request.remote_ip
}
```

After:

```
config.ip_resolver = -> {
  request.headers["X-Forwarded-For"]&.split(",")&.first&.strip || request.remote_ip
}
```

## [0.2.0] - 2025-11-28

### Breaking Changes

- Change the interface: `s/restrict_ip/filter_ip/g`

## [0.1.1] - 2025-11-28

### Maintenance

- Add a GitHub Action's workflow to publish the gem to RubyGems.org
- Add the co-mainteners

## [0.1.0] - 2025-11-28

- Initial release

