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
