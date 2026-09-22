<?php
declare(strict_types=1);

namespace App\Models;

final class ApiClient
{
    public function __construct(private readonly string $entry)
    {
    }

    public function entry(): string
    {
        return $this->entry;
    }

    /** @param array<string,mixed> $query @return array<string,mixed> */
    public function get(string $route, array $query = [], ?string $token = null): array
    {
        return $this->request('GET', $route, $query, null, $token);
    }

    /** @param array<string,mixed> $body @return array<string,mixed> */
    public function post(string $route, array $body = [], ?string $token = null): array
    {
        return $this->request('POST', $route, [], $body, $token);
    }

    /** @param array<string,mixed> $query @return array<string,mixed> */
    public function delete(string $route, array $query = [], ?string $token = null): array
    {
        return $this->request('DELETE', $route, $query, null, $token);
    }

    /** @return array<string,mixed> */
    public function upload(string $route, string $filePath, string $fileName, ?string $token = null): array
    {
        $url = $this->entry . '?' . http_build_query(['r' => $route]);
        $headers = ['Accept: application/json'];
        if ($token !== null && $token !== '') {
            $headers[] = 'Authorization: Bearer ' . $token;
            $headers[] = 'X-Auth-Token: ' . $token;
        }

        $ch = curl_init($url);
        curl_setopt_array($ch, $this->curlBaseOptions($headers) + [
            CURLOPT_CUSTOMREQUEST => 'POST',
            CURLOPT_POSTFIELDS => [
                'file' => new \CURLFile(
                    $filePath,
                    mime_content_type($filePath) ?: 'application/octet-stream',
                    $fileName
                ),
            ],
            CURLOPT_TIMEOUT => 60,
        ]);
        $raw = curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($raw === false || $raw === '') {
            return ['ok' => false, 'status' => $status ?: 0, 'error' => $error !== '' ? $error : 'تعذر رفع الملف'];
        }

        return $this->decodeResponse((string) $raw, $status, true);
    }

    /** @param array<string,mixed> $query @param array<string,mixed>|null $body @return array<string,mixed> */
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
            $headers[] = 'X-Auth-Token: ' . $token;
        }

        $ch = curl_init($url);
        $opts = $this->curlBaseOptions($headers) + [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_TIMEOUT => 90,
        ];
        if ($body !== null) {
            $opts[CURLOPT_POSTFIELDS] = json_encode($body, JSON_UNESCAPED_UNICODE);
        }
        curl_setopt_array($ch, $opts);

        $raw = curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($raw === false || $raw === '') {
            return [
                'ok' => false,
                'status' => $status ?: 0,
                'error' => $error !== '' ? ('تعذر الاتصال بخدمة API: ' . $error) : 'تعذر الاتصال بخدمة API',
                'api_entry' => $this->entry,
            ];
        }

        return $this->decodeResponse((string) $raw, $status, false);
    }

    /** @param list<string> $headers @return array<int,mixed> */
    private function curlBaseOptions(array $headers): array
    {
        return [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_MAXREDIRS => 3,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => 0,
            CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
            CURLOPT_USERAGENT => 'AqarTown-Web/1.0',
        ];
    }

    /** @return array<string,mixed> */
    private function decodeResponse(string $raw, int $status, bool $upload): array
    {
        $decoded = self::parseJsonPayload($raw);
        if (is_array($decoded)) {
            $decoded['status'] = $status;
            if (!array_key_exists('ok', $decoded) && $status >= 200 && $status < 300) {
                $decoded['ok'] = true;
            }

            return $decoded;
        }

        $snippet = self::snippet($raw);
        $hint = '';
        if (stripos($raw, '<html') !== false || stripos($raw, '<!DOCTYPE') !== false) {
            $hint = ' (الخادم أعاد صفحة HTML بدل JSON — تحقق من رابط api_entry ووجود api/index.php)';
        } elseif (stripos($raw, 'Parse error') !== false || stripos($raw, 'Fatal error') !== false) {
            $hint = ' (خطأ PHP في الـ API — راجع ملفات lib المرفوعة)';
        }

        return [
            'ok' => false,
            'status' => $status,
            'error' => ($upload ? 'استجابة رفع غير مفهومة' : 'استجابة غير مفهومة من خدمة API') . $hint,
            'api_entry' => $this->entry,
            'raw_snippet' => $snippet,
        ];
    }

    /** @return array<string,mixed>|null */
    public static function parseJsonPayload(string $raw): ?array
    {
        $raw = trim($raw);
        if ($raw === '') {
            return null;
        }
        // UTF-8 BOM
        if (str_starts_with($raw, "\xEF\xBB\xBF")) {
            $raw = substr($raw, 3);
        }
        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            return $decoded;
        }
        // تحذيرات PHP قبل JSON
        $start = strpos($raw, '{');
        $end = strrpos($raw, '}');
        if ($start !== false && $end !== false && $end > $start) {
            $slice = substr($raw, $start, $end - $start + 1);
            $decoded = json_decode($slice, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }
        $start = strpos($raw, '[');
        $end = strrpos($raw, ']');
        if ($start !== false && $end !== false && $end > $start) {
            $slice = substr($raw, $start, $end - $start + 1);
            $decoded = json_decode($slice, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        return null;
    }

    private static function snippet(string $raw): string
    {
        $oneLine = preg_replace('/\s+/', ' ', trim(strip_tags($raw))) ?? '';
        if (function_exists('mb_substr')) {
            return mb_substr($oneLine, 0, 160, 'UTF-8');
        }

        return substr($oneLine, 0, 160);
    }
}
