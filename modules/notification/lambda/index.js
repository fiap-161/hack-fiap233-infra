/**
 * Lambda: subscribed to SNS topic video-processing-failed.
 * Payload: { user_id, user_email, video_id, error_message }
 * Sends styled HTML email via SendGrid API (no recipient verification required).
 */
const https = require('https');

const SENDGRID_API_HOST = 'api.sendgrid.com';
const SENDGRID_PATH = '/v3/mail/send';

const HTML_TEMPLATE = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Processamento de vídeo</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f4f4f4;">
    <tr>
      <td align="center" style="padding: 24px 16px;">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); color: #ffffff; padding: 24px 32px; border-radius: 8px 8px 0 0;">
              <h1 style="margin: 0; font-size: 22px; font-weight: 600;">FiapX Videos</h1>
              <p style="margin: 8px 0 0 0; font-size: 14px; opacity: 0.95;">Notificação de processamento</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding: 32px;">
              <p style="margin: 0 0 16px 0; color: #202124; font-size: 16px; line-height: 1.5;">Olá,</p>
              <p style="margin: 0 0 16px 0; color: #5f6368; font-size: 15px; line-height: 1.5;">O processamento do seu vídeo <strong style="color: #1a73e8;">#{{video_id}}</strong> não foi concluído.</p>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f8f9fa; border-left: 4px solid #ea4335; border-radius: 4px; margin: 16px 0;">
                <tr>
                  <td style="padding: 16px;">
                    <p style="margin: 0; color: #5f6368; font-size: 14px;"><strong style="color: #ea4335;">Detalhe do erro:</strong></p>
                    <p style="margin: 8px 0 0 0; color: #202124; font-size: 14px;">{{error_message}}</p>
                  </td>
                </tr>
              </table>
              <p style="margin: 16px 0 0 0; color: #5f6368; font-size: 14px;">Você pode tentar um novo upload ou entrar em contato com o suporte se o problema persistir.</p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 16px 32px; border-radius: 0 0 8px 8px; border-top: 1px solid #e8eaed;">
              <p style="margin: 0; color: #9aa0a6; font-size: 12px;">Esta é uma mensagem automática. Por favor, não responda a este e-mail.</p>
              <p style="margin: 4px 0 0 0; color: #9aa0a6; font-size: 12px;">© FiapX Videos</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

function escapeHtml(text) {
  if (typeof text !== 'string') return String(text);
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function sendSendGridEmail(apiKey, fromEmail, fromName, toEmail, subject, html) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      personalizations: [{ to: [{ email: toEmail }] }],
      from: { email: fromEmail, name: fromName || 'FiapX Videos' },
      subject,
      content: [{ type: 'text/html', value: html }]
    });

    const options = {
      hostname: SENDGRID_API_HOST,
      path: SENDGRID_PATH,
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + apiKey,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body, 'utf8')
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve();
        } else {
          reject(new Error(`SendGrid ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.write(body, 'utf8');
    req.end();
  });
}

exports.handler = async (event) => {
  const apiKey = process.env.SENDGRID_API_KEY;
  const senderEmail = process.env.SENDER_EMAIL;
  const senderName = process.env.SENDER_NAME || 'FiapX Videos';
  const subject = process.env.EMAIL_SUBJECT || 'FiapX Videos — Erro no processamento do seu vídeo';

  if (!apiKey || !senderEmail) {
    console.error('Missing SENDGRID_API_KEY or SENDER_EMAIL');
    return { statusCode: 500 };
  }

  for (const record of event.Records || []) {
    if (record.Sns && record.Sns.Message) {
      let payload;
      try {
        payload = JSON.parse(record.Sns.Message);
      } catch (e) {
        console.error('Invalid SNS message JSON:', e);
        continue;
      }
      const { user_email, video_id, error_message } = payload;
      if (!user_email) {
        console.error('Missing user_email in payload');
        continue;
      }
      const videoId = video_id != null ? String(video_id) : '—';
      const errorMsg = error_message != null ? escapeHtml(String(error_message)) : 'Erro desconhecido.';
      const html = HTML_TEMPLATE
        .replace(/\{\{video_id\}\}/g, escapeHtml(videoId))
        .replace(/\{\{error_message\}\}/g, errorMsg);

      try {
        await sendSendGridEmail(apiKey, senderEmail, senderName, user_email, subject, html);
        console.log('Email sent to', user_email, 'for video', video_id);
      } catch (err) {
        console.error('SendGrid error:', err.message);
        throw err;
      }
    }
  }
  return { statusCode: 200 };
};
