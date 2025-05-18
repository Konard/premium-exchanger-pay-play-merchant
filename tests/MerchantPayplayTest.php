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
