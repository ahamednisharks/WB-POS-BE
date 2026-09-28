import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  PORT: Joi.number().port().default(3000),
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
  CORS_ORIGINS: Joi.string().default('http://localhost:4200'),
  PUBLIC_URL: Joi.string().uri().optional(),

  DB_HOST: Joi.string().default('localhost'),
  DB_PORT: Joi.number().port().default(3306),
  DB_USER: Joi.string().required(),
  DB_PASSWORD: Joi.string().allow('').required(),
  DB_NAME: Joi.string().required(),
  DB_POOL_LIMIT: Joi.number().integer().min(1).max(100).default(10),
  DB_SSL: Joi.boolean().default(false),
  DB_SSL_CA: Joi.string().allow('').optional(),

  JWT_SECRET: Joi.string().min(16).required(),
  JWT_EXPIRES: Joi.string().default('8h'),
  JWT_REMEMBER_EXPIRES: Joi.string().default('7d'),

  AES_KEY: Joi.string()
    .pattern(/^[0-9a-fA-F]{64}$/)
    .required()
    .messages({
      'string.pattern.base':
        'AES_KEY must be 64 hex characters (32 bytes). Generate one with: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"',
    }),

  UPLOAD_DIR: Joi.string().default('./uploads'),
  MAX_IMAGE_MB: Joi.number().positive().default(1),
  MAX_DOC_MB: Joi.number().positive().default(2),
  MAX_INVOICE_MB: Joi.number().positive().default(5),
});
