# SwiftKeychain

Secure credential storage using the macOS Keychain.

[:fontawesome-brands-github: GitHub](https://github.com/jagtesh/swiftkeychain) · [:fontawesome-brands-python: PyPI](https://pypi.org/project/swiftkeychain/)

## Install

```bash
pip install swiftkeychain
```

## API

| Function | Description |
|----------|-------------|
| `set_password(service, account, password)` | Store a generic password |
| `get_password(service, account)` → `str?` | Retrieve a password (None if missing) |
| `delete_password(service, account)` → `bool` | Delete a password |
| `find_passwords(service)` → `list[str]` | Find all accounts for a service |
| `set_internet_password(server, account, password)` | Store an internet password |
| `get_internet_password(server, account)` → `str?` | Retrieve an internet password |

## Usage

```python
import swiftkeychain as kc

# Store credentials
kc.set_password("myapp", "user@email.com", "s3cret-p@ss!")
kc.set_password("myapp", "admin@email.com", "adm1n-p@ss!")

# Retrieve
password = kc.get_password("myapp", "user@email.com")
print(password)  # → "s3cret-p@ss!"

# Find all accounts
accounts = kc.find_passwords("myapp")
print(accounts)  # → ["user@email.com", "admin@email.com"]

# Delete
kc.delete_password("myapp", "admin@email.com")

# Internet passwords
kc.set_internet_password("api.example.com", "token", "t0k3n-xyz")
token = kc.get_internet_password("api.example.com", "token")

# Missing passwords return None
missing = kc.get_password("myapp", "nobody")
print(missing)  # → None
```

## Swift Source

The underlying Swift code uses the `Security` framework:

```swift
@PyFunction
func set_password(service: String, account: String, password: String) throws {
    let query: NSDictionary = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecValueData: password.data(using: .utf8)!,
    ]
    SecItemDelete(query)
    let status = SecItemAdd(query, nil)
    if status != errSecSuccess {
        throw KeychainBridgeError.operationFailed(keychainErrorMessage(status))
    }
}
```

[:octicons-arrow-right-24: Full source on GitHub](https://github.com/jagtesh/swiftkeychain/blob/main/swift/Sources/SwiftKeychain/SwiftKeychain.swift)
