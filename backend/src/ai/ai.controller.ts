import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AiService } from './ai.service';
import { AskAiDto } from './dto/ask-ai.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('ai')
@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('ask')
  ask(@Body() dto: AskAiDto, @CurrentUser() actor: { id: string }) {
    return this.aiService.ask(dto.question, actor?.id, dto.conversationId);
  }

  @Get('conversations')
  listConversations(@CurrentUser() actor: { id: string }) {
    return this.aiService.listConversations(actor?.id);
  }

  @Get('conversations/:id')
  getConversation(@Param('id') id: string) {
    return this.aiService.getConversation(id);
  }
}
