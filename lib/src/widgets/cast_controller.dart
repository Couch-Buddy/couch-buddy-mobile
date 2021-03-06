import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chromecast_api/chromecast_api.dart';
import 'package:flutter/material.dart';

class CastController extends StatefulWidget {
  CastController({ Key key }) : super(key: key);

  @override
  _CastControllerState createState() => _CastControllerState();
}

class _CastControllerState extends State<CastController> {
  StreamSubscription _castStateSubscription;
  StreamSubscription _mediaStateSubscription;

  MediaInfo _currentMedia;
  PlayerState _playerState;

  @override
  void initState() {
    _castStateSubscription = ChromecastApi.castEventStream.listen((event) {
      if (event != 4) {
        setState(() { _currentMedia = null; });
      }
    });

    _mediaStateSubscription = ChromecastApi.mediaEventStream.listen((mediaEvent) {
      setState(() {
        _currentMedia = mediaEvent['mediaInfo'] != null
          ? MediaInfo.fromMap(Map<String, dynamic>.from(mediaEvent['mediaInfo']))
          : null;

        _playerState = PlayerState.values[mediaEvent['playerState'] as int];
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _castStateSubscription.cancel();
    _mediaStateSubscription.cancel();

    super.dispose();
  }

  void _activateSubtitles(int id) {
    ChromecastApi.activateSubtitles(id);
  }

  void _showSubtitlesDialog() async {
    final int selectedSubtitlesId = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _buildDialog()
    );

    if (selectedSubtitlesId != null) {
      _activateSubtitles(selectedSubtitlesId > 0 ? selectedSubtitlesId : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMedia == null) { return Container(); }

    String subtitle;

    if (_currentMedia.type == MediaMetadataType.TV_SHOW) {
      subtitle = '';

      if (_currentMedia.season != null && _currentMedia.episode != null) {
        subtitle += 'S${_currentMedia.season} E${_currentMedia.episode} ';
      }

      if (_currentMedia.seriesTitle != null) {
        subtitle += _currentMedia.seriesTitle;
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: _currentMedia.images.length > 0
            ? CachedNetworkImage(
                imageUrl: _currentMedia.images[0].toString(),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              )
            : Container(
                color: Colors.grey,
                width: 64,
                height: 64,
              ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentMedia.title,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.bodyText1,
                ),
                subtitle != null
                ? Text(
                  subtitle,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.caption,
                )
                : Container(),
              ],
            ),
          ),
          ButtonBar(
            children: <Widget>[
              IconButton(
                icon: Icon(_playerState == PlayerState.PLAYING ? Icons.pause : Icons.play_arrow),
                onPressed: _playerState == PlayerState.PLAYING || _playerState == PlayerState.PAUSED
                  ? ChromecastApi.playOrPause
                  : null
              ),

              IconButton(
                icon: Icon(Icons.closed_caption),
                onPressed: () => _showSubtitlesDialog()
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialog() {
    if (_currentMedia == null) { return Container(); }

    return SimpleDialog(
      title: const Text('Subtitles'),
      children: _currentMedia.subtitles.map((subs) => SimpleDialogOption(
        onPressed: () => Navigator.pop(context, subs.id),
        child: ListTile(
          title: Text(subs.name ?? subs.lang),
          trailing: subs.active ? Icon(Icons.check) : Container(width: 1,),
          dense: true,
          selected: subs.active,
        ),
      )).toList()
      ..add(SimpleDialogOption(
        onPressed: () => Navigator.pop(context, -1),
        child: ListTile(
          dense: true,
          trailing: Icon(Icons.not_interested),
          title: Text('No Subtitles')
        )
      ))
    );
  }
}