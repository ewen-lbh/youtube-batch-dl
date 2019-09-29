#include "youtube_batch_dl.h"

VALUE rb_mYoutubeBatchDL;

void
Init_youtube_batch_dl(void)
{
  rb_mYoutubeBatchDL = rb_define_module("YoutubeBatchDL");
}
