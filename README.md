# PayPlay ↔ Premium Exchanger — Merchant Module Test Harness

Quick-start repository that lets you **develop, stub and unit-test** a  
*PayPlay* merchant (invoice / pay-in) gateway module compatible with **Premium Exchanger** ≥ 2.6.

``\`\`
repo root
├── src/
│   └── Merchant_payplay.php          ← gateway implementation
├── tests/
│   └── MerchantPayplayTest.php       ← PHPUnit tests
├── bootstrap.php                     ← autoload helper for tests
├── composer.json                     ← dev dependencies (phpunit)
└── .gitignore
``\`\`

## Usage

``\`\`bash
composer install
./vendor/bin/phpunit
``\`\`

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
