import 'package:synctv_app/contracts/web_playback_site.dart';

Uri officialSiteLoginEntryUri(WebPlaybackProvider provider) =>
    switch (provider) {
      WebPlaybackProvider.iqiyi => Uri.https(
        'www.iqiyi.com',
        '/iframe/loginreg',
      ),
      WebPlaybackProvider.tencentVideo => Uri.https('v.qq.com', '/'),
    };

String officialSiteLoginProviderName(WebPlaybackProvider provider) =>
    switch (provider) {
      WebPlaybackProvider.iqiyi => '爱奇艺',
      WebPlaybackProvider.tencentVideo => '腾讯视频',
    };
