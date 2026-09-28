import { Module } from '@nestjs/common';
import { LoginAccountController } from './login-account.controller';
import { LoginAccountRepository } from './login-account.repository';
import { LoginAccountService } from './login-account.service';

@Module({
  controllers: [LoginAccountController],
  providers: [LoginAccountRepository, LoginAccountService],
})
export class LoginAccountModule {}
