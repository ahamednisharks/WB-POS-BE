import { BadRequestException, INestApplication, ValidationError, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';
import { AppConfig } from './config/configuration';

function isEmpty(value: unknown): boolean {
  return value === undefined || value === null || (typeof value === 'string' && value.trim() === '');
}

/**
 * class-validator lists constraints bottom decorator first; the top one (type check) is the most useful,
 * and for a missing value a "... is required" message beats "must be shorter than ...".
 */
function firstError(errors: ValidationError[], path = ''): { field: string; message: string } | null {
  for (const e of errors) {
    const field = path ? `${path}.${e.property}` : e.property;
    const messages = e.constraints ? Object.values(e.constraints) : [];
    let message: string | undefined;
    if (messages.length && isEmpty(e.value)) message = messages.find((m) => /required/i.test(m)) ?? `${e.property} is required`;
    else message = messages[messages.length - 1];
    if (message) return { field, message };
    const nested = firstError(e.children ?? [], field);
    if (nested) return nested;
  }
  return null;
}

/** Shared by main.ts and the e2e tests so both run the exact same pipeline. */
export function configureApp(app: NestExpressApplication): void {
  const config = app.get(ConfigService<AppConfig, true>);

  app.setGlobalPrefix('api');
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' }, contentSecurityPolicy: false }));
  app.enableCors({ origin: config.get('corsOrigins', { infer: true }), credentials: true, exposedHeaders: ['Content-Disposition', 'x-request-id'] });
  // Images and ID proofs arrive inline as data: URLs, so JSON bodies can be a few MB.
  app.useBodyParser('json', { limit: '12mb' });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      exceptionFactory: (errors: ValidationError[]) => {
        const first = firstError(errors);
        const field = first?.field.split('.')[0];
        return new BadRequestException({ message: first?.message ?? 'Invalid request', ...(field ? { field } : {}) });
      },
    }),
  );
  app.useStaticAssets(config.get('uploads', { infer: true }).dir, { prefix: '/uploads', maxAge: '7d' });
  app.enableShutdownHooks();
}

export function setupSwagger(app: INestApplication): void {
  const doc = new DocumentBuilder()
    .setTitle('WB-POS API')
    .setDescription(
      'Bakery billing backend. Every database operation is a MySQL stored procedure.\n\n' +
        'Responses: `{ success, message?, data }` or `{ success, data: [...], total }` for lists. ' +
        'Errors: `{ success: false, statusCode, message, field? }`.',
    )
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, doc), {
    swaggerOptions: { persistAuthorization: true },
  });
}

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  configureApp(app);
  setupSwagger(app);
  const port = app.get(ConfigService<AppConfig, true>).get('port', { infer: true });
  await app.listen(port);
  app.get(Logger).log(`WB-POS API listening on http://localhost:${port}/api (docs: /api/docs)`);
}

if (require.main === module) {
  void bootstrap();
}
