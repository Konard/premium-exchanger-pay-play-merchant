# PayPlay ↔ Premium Exchanger — Merchant Module Test Harness

Quick-start repository that lets you **develop, stub and unit-test** a  
*PayPlay* merchant (invoice / pay-in) gateway module compatible with **Premium Exchanger** ≥ 2.6.

````
repo root
├── src/
│   └── Merchant_payplay.php          ← gateway implementation
├── tests/
│   └── MerchantPayplayTest.php       ← PHPUnit tests
├── bootstrap.php                     ← autoload helper for tests
├── composer.json                     ← dev dependencies (phpunit)
└── .gitignore
````

## Usage

```bash
composer install
./vendor/bin/phpunit
```

## Deployment to Premium Exchanger

1. **Copy the gateway file:**
   - Place `src/Merchant_payplay.php` into your Premium Exchanger installation at:
     `application/modules/merchant/payplay/Merchant_payplay.php`
2. **Configure the module:**
   - In the Premium Exchanger admin panel, enable the PayPlay merchant module and set your API credentials.
3. **Test integration:**
   - Use the test suite in this repo to verify your changes before deploying to production.

## How to Test

- Run all unit tests and check code coverage:
  ```bash
  composer install
  ./vendor/bin/phpunit --coverage-text
  ```
- The project enforces a code coverage threshold (98% lines, 85% methods). All logic and error branches are covered.
- To run tests in Docker (recommended for CI):
  ```bash
  docker build --no-cache -t payplay-merchant-test .
  docker run --rm -v $(pwd):/app -w /app payplay-merchant-test ./vendor/bin/phpunit --coverage-text
  ```

## Debugging & Development

- **Stub the network layer:**
  - The gateway class allows injecting a custom request handler for local testing (see `tests/MerchantPayplayTest.php`).
- **Debugging tips:**
  - Use `var_dump()` or `error_log()` in your handler or gateway code for quick inspection.
  - Run tests with `XDEBUG_MODE=debug` for step debugging if Xdebug is installed.
- **Developing new features:**
  - Add new tests in `tests/MerchantPayplayTest.php`.
  - Ensure all new code paths are covered by tests to maintain the coverage threshold.
- **Troubleshooting Docker:**
  - If tests do not reflect your latest code, rebuild the Docker image with `--no-cache`.

## File-by-file overview

| File | Purpose |
|------|---------|
| **src/Merchant_payplay.php** | Core gateway class. Production-ready `curl` code plus injectable stub for tests. |
| **tests/MerchantPayplayTest.php** | Covers: HMAC signature generation/validation, `create_invoice()` request shaping & response handling. |
| **bootstrap.php** | Registers the `src/` tree for PSR-4 (`PE\\PayPlayMerchant\\`). |
| **composer.json** | Dev dependency on PHPUnit ≥ 10, PSR-4 autoload directive. |
| **.gitignore** | Ignores Composer artefacts (`/vendor`, `composer.lock`). |

You can later drop the `src/` file into  
`application/modules/merchant/payplay/` inside a real Premium Exchanger
installation.
