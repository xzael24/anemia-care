import {
  BadRequestException,
  Controller,
  Get,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  DISCLAIMER,
  ScreeningRecord,
  ScreeningService,
} from './screening.service';

@Controller('screening')
export class ScreeningController {
  constructor(private readonly screenings: ScreeningService) {}

  @Post()
  @UseInterceptors(FileInterceptor('photo'))
  async screen(@UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('Foto wajib dikirim di field "photo"');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('File harus berupa gambar');
    }
    const record = await this.screenings.screen(file);
    return { ...record, disclaimer: DISCLAIMER };
  }

  @Get()
  async history(): Promise<ScreeningRecord[]> {
    return this.screenings.history();
  }
}