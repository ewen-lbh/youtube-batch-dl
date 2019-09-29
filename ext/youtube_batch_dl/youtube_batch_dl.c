#include "youtube_batch_dl.h"

VALUE rb_mYoutubeBatchDl;

void
Init_youtube_batch_dl(void)
{
  rb_mYoutubeBatchDl = rb_define_module("YoutubeBatchDl");
}
