<?php
/**
 * ProgressReporter — отчёт курса о прогрессе ученика в единый API прогресса
 * (auth-web /api/progress.php).
 *
 * Канонический источник: shared/php/progress-reporter/ProgressReporter.php
 * Используется сервер-к-серверу (доверенные IP auth-web) для курсов с
 * собственным серверным прогрессом (python-web, ai-web), чтобы сводная
 * карточка ученика на портале учитывала все курсы.
 */
if (!class_exists('ProgressReporter')) {
    class ProgressReporter
    {
        private static function authUrl(): string
        {
            if (defined('AUTH_URL')) {
                return AUTH_URL;
            }
            return 'https://auth.nayanovaacademy.ru';
        }

        /**
         * Сообщить сводку курса: модуль '__summary__' → data {completed,total}.
         * Никогда не бросает исключений — лучший-эффект-обновление.
         */
        public static function report(int $userId, string $course, int $completed, int $total): bool
        {
            try {
                if ($completed < 0) {
                    $completed = 0;
                }
                if ($total < 1) {
                    return false;
                }

                $payload = json_encode([
                    'course'     => $course,
                    'module'     => '__summary__',
                    'completed'  => 1,
                    'data'       => ['completed' => $completed, 'total' => $total],
                    'user_id'    => $userId,
                ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

                $ch = curl_init(self::authUrl() . '/api/progress.php');
                curl_setopt_array($ch, [
                    CURLOPT_POST          => true,
                    CURLOPT_POSTFIELDS    => $payload,
                    CURLOPT_HTTPHEADER    => ['Content-Type: application/json'],
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_TIMEOUT       => 5,
                    CURLOPT_SSL_VERIFYPEER => true,
                    CURLOPT_FOLLOWLOCATION => false,
                ]);
                $response = curl_exec($ch);
                $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                curl_close($ch);

                return $response !== false && $httpCode === 200;
            } catch (Throwable $e) {
                return false;
            }
        }
    }
}
