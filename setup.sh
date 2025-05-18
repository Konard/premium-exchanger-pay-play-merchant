#!/usr/bin/env bash
# -----------------------------------------------------------------------
# create-pe-payplay-merchant-repo.sh
# -----------------------------------------------------------------------
# Generates a self-contained repository for developing & testing a
# PayPlay *merchant* (pay-in) module compatible with Premium Exchanger.
# -----------------------------------------------------------------------
set -euo pipefail

REPO="pe-payplay-merchant-test"
[ -d "$REPO" ] && { echo "Directory '$REPO' already exists. Aborting."; exit 1; }

echo "› Creating repository skeleton: $REPO"
mkdir -p "$REPO"/{src,tests}

############################################################################
# 1. README.md
############################################################################
cat <<'EOF' >"$REPO/README.md"
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
EOF

############################################################################
# 2. composer.json
############################################################################
cat <<'EOF' >"$REPO/composer.json"
{
  "name": "premiumexchanger/payplay-merchant-test",
  "description": "Test harness for PayPlay merchant module (Premium Exchanger)",
  "license": "MIT",
  "require": {
    "php": ">=8.1"
  },
  "require-dev": {
    "phpunit/phpunit": "^10"
  },
  "autoload": {
    "psr-4": {
      "PE\\PayPlayMerchant\\": "src/"
    }
  },
  "minimum-stability": "stable"
}
EOF

############################################################################
# 3. .gitignore
############################################################################
cat <<'EOF' >"$REPO/.gitignore"
/vendor
composer.lock
/.idea
.DS_Store
EOF

############################################################################
# 4. bootstrap.php
############################################################################
cat <<'PHP' >"$REPO/bootstrap.php"
<?php
// Lightweight bootstrap so tests can `require __DIR__.'/../bootstrap.php'`
require __DIR__ . '/vendor/autoload.php';
PHP

############################################################################
# 5. src/Merchant_payplay.php
############################################################################
cat <<'PHP' >"$REPO/src/Merchant_payplay.php"
<?php
/**
 * Merchant_payplay — PayPlay invoice gateway for Premium Exchanger.
 *
 *  • create_invoice(array $order): array   → ['redirect' => <pay_url>]
 *  • verify_ipn(array $headers,string $payload): array
 *
 * Network layer is injectable for tests; falls back to cURL in prod.
 */
namespace PE\PayPlayMerchant;

class Merchant_payplay
{
    private string $apiKey;
    private string $apiSecret;
    private string $baseUrl;
    /** @var callable(string $method,string $url,string $body,array $hdrs):string */
    private $requestHandler;

    public function __construct(array $cfg, callable $requestHandler = null)
    {
        $this->apiKey         = $cfg['api_key']    ?? 'demo_key';
        $this->apiSecret      = $cfg['api_secret'] ?? 'demo_secret';
        $this->baseUrl        = rtrim($cfg['api_url'] ?? 'https://api.payplay.io', '/');
        $this->requestHandler = $requestHandler ?? [$this, 'curlRequest'];
    }

    /** Create PayPlay invoice and return redirect URL wrapper. */
    public function create_invoice(array $order): array
    {
        $body = [
            'amount'       => (string) $order['amount_send'],
            'asset'        => $order['currency_send'],
            'external_id'  => (string) $order['id'],
            'callback_url' => $order['callback_url'] ?? 'https://example.com/webhook',
        ];

        $resp = $this->signedRequest('POST', '/v1/invoices', $body);

        return ['redirect' => $resp['payment_url'] ?? '#'];
    }

    /** Validate and parse webhook payload. */
    public function verify_ipn(array $headers, string $payload): array
    {
        $ts   = $headers['X-PAYPLAY-TIMESTAMP'] ?? '';
        $calc = hash_hmac('sha256', "{$ts}\n{$payload}", $this->apiSecret);
        if (!hash_equals($calc, $headers['X-PAYPLAY-CB-SIGN'] ?? '')) {
            throw new \RuntimeException('Bad signature');
        }
        $data = json_decode($payload, true);
        if (!is_array($data)) {
            throw new \RuntimeException('Invalid JSON');
        }
        return $data; // caller decides CONFIRMED etc.
    }

    /* ------------------------------------------------------------------ */

    private function signedRequest(string $method, string $path, array $body = [])
    {
        $timestamp    = (string) ((int) (microtime(true) * 1000));
        $jsonBody     = $body ? json_encode($body, JSON_UNESCAPED_SLASHES) : '';
        $stringToSign = "{$timestamp}\n{$method}\n{$path}\n{$jsonBody}";
        $sign         = hash_hmac('sha256', $stringToSign, $this->apiSecret);

        $headers = [
            "Content-Type: application/json",
            "X-PAYPLAY-KEY: {$this->apiKey}",
            "X-PAYPLAY-TIMESTAMP: {$timestamp}",
            "X-PAYPLAY-SIGN: {$sign}",
        ];
        $url  = $this->baseUrl . $path;
        $resp = call_user_func($this->requestHandler, $method, $url, $jsonBody, $headers);

        $data = json_decode($resp, true);
        if (!is_array($data)) {
            throw new \RuntimeException("Invalid JSON from PayPlay: $resp");
        }
        if (($data['status'] ?? 'SUCCESS') !== 'SUCCESS') {
            throw new \RuntimeException("PayPlay error payload: $resp");
        }
        return $data['data'] ?? $data;
    }

    /** Default HTTP implementation using cURL. */
    private function curlRequest(string $method, string $url, string $body, array $headers): string
    {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST  => $method,
            CURLOPT_POSTFIELDS     => $body ?: null,
            CURLOPT_HTTPHEADER     => $headers,
        ]);
        $out = curl_exec($ch);
        if ($out === false) {
            throw new \RuntimeException('cURL error: ' . curl_error($ch));
        }
        return $out;
    }

    /* Helpers for unit tests ------------------------------------------ */

    public static function sign_request(string $secret, string $stringToSign): string
    {
        return hash_hmac('sha256', $stringToSign, $secret);
    }

    public static function sign_callback(string $secret, string $timestamp, string $payload): string
    {
        return hash_hmac('sha256', "{$timestamp}\n{$payload}", $secret);
    }
}
PHP

############################################################################
# 6. tests/MerchantPayplayTest.php
############################################################################
cat <<'PHP' >"$REPO/tests/MerchantPayplayTest.php"
<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;
use PE\PayPlayMerchant\Merchant_payplay;

require_once dirname(__DIR__, 1) . '/bootstrap.php';

final class MerchantPayplayTest extends TestCase
{
    /** Ensures create_invoice() shapes request and parses response. */
    public function testCreateInvoiceShapesRequest(): void
    {
        $captured = [];

        $stubHandler = function (
            string $method,
            string $url,
            string $body,
            array  $hdrs
        ) use (&$captured): string {
            $captured = compact('method', 'url', 'body', 'hdrs');
            return json_encode([
                'status' => 'SUCCESS',
                'data'   => ['payment_url' => 'https://payplay/pay/i123']
            ]);
        };

        $gw = new Merchant_payplay(
            ['api_key' => 'k', 'api_secret' => 's', 'api_url' => 'https://mock'],
            $stubHandler
        );

        $order  = ['id' => 99, 'amount_send' => 250, 'currency_send' => 'BTC',
                   'callback_url' => 'https://me/cb'];
        $reply  = $gw->create_invoice($order);

        $req = json_decode($captured['body'], true);
        $this->assertSame('250',   $req['amount']);
        $this->assertSame('BTC',   $req['asset']);
        $this->assertSame('99',    $req['external_id']);
        $this->assertSame('https://me/cb', $req['callback_url']);

        $this->assertSame('https://payplay/pay/i123', $reply['redirect']);
    }

    /** Verifies verify_ipn() correctly validates signature. */
    public function testVerifyIpnSignature(): void
    {
        $gw = new Merchant_payplay(['api_secret' => 'secret']);

        $payload = json_encode(['external_id' => '99', 'status' => 'CONFIRMED']);
        $ts      = '123';
        $sign    = Merchant_payplay::sign_callback('secret', $ts, $payload);

        $data = $gw->verify_ipn(
            ['X-PAYPLAY-TIMESTAMP' => $ts, 'X-PAYPLAY-CB-SIGN' => $sign],
            $payload
        );

        $this->assertSame('CONFIRMED', $data['status']);
    }

    /** Checks raw request-signing helper parity. */
    public function testRequestSignatureHelper(): void
    {
        $toSign = "123\nPOST\n/v1/invoices\n{\"amount\":\"1\"}";
        $this->assertSame(
            hash_hmac('sha256', $toSign, 'secret'),
            Merchant_payplay::sign_request('secret', $toSign)
        );
    }
}
PHP

echo "› All files generated."
echo "› Next steps:"
echo "   cd $REPO && composer install && ./vendor/bin/phpunit"