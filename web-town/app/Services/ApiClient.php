<?php
declare(strict_types=1);

final class ApiClient
{
    public function __construct(private readonly string $entry)
    {
    }

    /**
     * @param array<string,mixed> $query
     * @return array<string,mixed>
     */
    public function get(string $route, array $query = [], ?string $token = null): array
    {
        return $this->request('GET', $route, $query, null, $token);
    }

    /**
     * @param array<string,mixed> $body
     * @return array<string,mixed>
     */
    public function post(string $route, array $body = [], ?string $token = null): array
    {
        return $this->request('POST', $route, [], $body, $token);
    }

    /**
     * @param array<string,mixed> $query
     * @return array<string,mixed>
     */
    public function delete(string $route, array $query = [], ?string $token = null): array
    {
        return $this->request('DELETE', $route, $query, null, $token);
    }

    /**
     * @return array<string,mixed>
     */
    public function upload(string $route, string $filePath, string $fileName, ?string $token = null): array
    {
        $url = $this->entry . '?' . http_build_query(['r' => $route]);
        $headers = ['Accept: application/json'];
        if ($token !== null && $token !== '') {
            $headers[] = 'Authorization: Bearer ' . $token;
        }

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => 'POST',
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_POSTFIELDS => [
                'file' => new CURLFile($filePath, mime_content_type($filePath) ?: 'application/octet-stream', $fileName),
            ],
        ]);
        $raw = curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($raw === false || $raw === '') {
            return ['ok' => false, 'status' => $status ?: 0, 'error' => $error !== '' ? $error : 'تعذر رفع الملف'];
        }
        $decoded = json_decode((string) $raw, true);
        if (!is_array($decoded)) {
            return ['ok' => false, 'status' => $status, 'error' => 'استجابة رفع غير مفهومة'];
        }
        $decoded['status'] = $status;
        return $decoded;
    }

    /**
     * @param array<string,mixed> $query
     * @param array<string,mixed>|null $body
     * @return array<string,mixed>
     */
    private function request(string $method, string $route, array $query = [], ?array $body = null, ?string $token = null): array
    {
        $query = array_merge(['r' => $route], $query);
        $url = $this->entry . '?' . http_build_query($query);
        $headers = [
            'Accept: application/json',
            'Content-Type: application/json; charset=utf-8',
        ];
        if ($token !== null && $token !== '') {
            $headers[] = 'Authorization: Bearer ' . $token;
        }

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 15,
        ]);
        if ($body !== null) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body, JSON_UNESCAPED_UNICODE));
        }

        $raw = curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($raw === false || $raw === '') {
            return [
                'ok' => false,
                'status' => $status ?: 0,
                'error' => $error !== '' ? $error : 'تعذر الاتصال بخدمة API',
            ];
        }

        $decoded = json_decode((string) $raw, true);
        if (!is_array($decoded)) {
            return [
                'ok' => false,
                'status' => $status,
                'error' => 'استجابة غير مفهومة من خدمة API',
            ];
        }

        $decoded['status'] = $status;
        return $decoded;
    }
}

function api_client(): ApiClient
{
    static $client = null;
    if ($client === null) {
        $client = new ApiClient((string) app_config('api_entry'));
    }

    return $client;
}
