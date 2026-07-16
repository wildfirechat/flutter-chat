class VideoProfile {
  static const int VP120P = 0;
  static const int VP120P_3 = 2;
  static const int VP180P = 10;
  static const int VP180P_3 = 12;
  static const int VP180P_4 = 13;
  static const int VP240P = 20;
  static const int VP240P_3 = 22;
  static const int VP240P_4 = 23;
  static const int VP360P = 30;
  static const int VP360P_3 = 32;
  static const int VP360P_4 = 33;
  static const int VP360P_6 = 35;
  static const int VP360P_7 = 36;
  static const int VP360P_8 = 37;
  static const int VP480P = 40;
  static const int VP480P_3 = 42;
  static const int VP480P_4 = 43;
  static const int VP480P_6 = 45;
  static const int VP480P_8 = 47;
  static const int VP480P_9 = 48;
  static const int VP720P = 50;
  static const int VP720P_3 = 52;
  static const int VP720P_5 = 54;
  static const int VP720P_6 = 55;
  static const int VP1080P = 60;
  static const int VP1080P_3 = 62;
  static const int VP1080P_5 = 64;
  static const int VPDEFAULT = VP480P;

  int width = 0;
  int height = 0;
  int fps = 30;
  int bitrate = 100;

  VideoProfile(this.width, this.height, this.fps, this.bitrate);

  static VideoProfile getVideoProfile(int ce) {
    switch (ce) {
      case VP120P:
        return VideoProfile(160, 120, 15, 120);
      case VP120P_3:
        return VideoProfile(120, 120, 15, 100);
      case VP180P:
        return VideoProfile(320, 180, 15, 280);
      case VP180P_3:
        return VideoProfile(180, 180, 15, 200);
      case VP180P_4:
        return VideoProfile(240, 180, 15, 240);
      case VP240P:
        return VideoProfile(320, 240, 15, 360);
      case VP240P_3:
        return VideoProfile(240, 240, 15, 240);
      case VP240P_4:
        return VideoProfile(424, 240, 15, 400);
      case VP360P:
        return VideoProfile(640, 360, 15, 800);
      case VP360P_3:
        return VideoProfile(360, 360, 15, 520);
      case VP360P_4:
        return VideoProfile(640, 360, 30, 1200);
      case VP360P_6:
        return VideoProfile(360, 360, 30, 780);
      case VP360P_7:
        return VideoProfile(480, 360, 15, 1000);
      case VP360P_8:
        return VideoProfile(480, 360, 30, 1500);
      case VP480P:
        return VideoProfile(640, 480, 15, 1000);
      case VP480P_3:
        return VideoProfile(480, 480, 15, 800);
      case VP480P_4:
        return VideoProfile(640, 480, 30, 1500);
      case VP480P_6:
        return VideoProfile(480, 480, 30, 1200);
      case VP480P_8:
        return VideoProfile(848, 480, 15, 1200);
      case VP480P_9:
        return VideoProfile(848, 480, 30, 1800);
      case VP720P:
        return VideoProfile(1280, 720, 15, 2400);
      case VP720P_3:
        return VideoProfile(1280, 720, 30, 3600);
      case VP720P_5:
        return VideoProfile(960, 720, 15, 1920);
      case VP720P_6:
        return VideoProfile(960, 720, 30, 2880);
      case VP1080P:
        return VideoProfile(1920, 1080, 15, 4200);
      case VP1080P_3:
        return VideoProfile(1920, 1080, 30, 6300);
      case VP1080P_5:
        return VideoProfile(1920, 1080, 60, 9560);
      default:
        return getVideoProfile(VPDEFAULT);
    }
  }
}
