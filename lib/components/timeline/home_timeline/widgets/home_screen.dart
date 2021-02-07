import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:harpy/components/common/dialogs/changelog_dialog.dart';
import 'package:harpy/components/common/dialogs/harpy_exit_dialog.dart';
import 'package:harpy/components/common/list/scroll_direction_listener.dart';
import 'package:harpy/components/common/list/scroll_to_start.dart';
import 'package:harpy/components/common/list/slivers/sliver_fill_loading_indicator.dart';
import 'package:harpy/components/common/misc/harpy_scaffold.dart';
import 'package:harpy/components/compose/widget/compose_screen.dart';
import 'package:harpy/components/settings/layout/widgets/layout_padding.dart';
import 'package:harpy/components/timeline/home_timeline/widgets/home_drawer.dart';
import 'package:harpy/components/timeline/new/home_timeline/bloc/home_timeline_bloc.dart';
import 'package:harpy/components/tweet/widgets/tweet_list.dart';
import 'package:harpy/core/api/twitter/tweet_data.dart';
import 'package:harpy/core/service_locator.dart';
import 'package:harpy/misc/harpy_navigator.dart';

import 'home_app_bar.dart';

/// The home screen for an authenticated user.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.autoLogin = false,
  });

  /// Whether the user got automatically logged in when opening the app
  /// (previous session got restored).
  final bool autoLogin;

  static const String route = 'home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  bool _showFab = true;

  @override
  void initState() {
    super.initState();

    if (widget.autoLogin == true) {
      ChangelogDialog.maybeShow(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    app<HarpyNavigator>().routeObserver.subscribe(this, ModalRoute.of(context));
  }

  @override
  void dispose() {
    super.dispose();
    app<HarpyNavigator>().routeObserver.unsubscribe(this);
  }

  @override
  void didPopNext() {
    // force a rebuild when the home screen shows again
    setState(() {});
  }

  void _onScrollDirectionChanged(VerticalDirection direction) {
    final bool show = direction != VerticalDirection.down;

    if (_showFab != show) {
      setState(() {
        _showFab = show;
      });
    }
  }

  Widget _buildFloatingActionButton() {
    if (_showFab) {
      return FloatingActionButton(
        onPressed: () => app<HarpyNavigator>().pushNamed(ComposeScreen.route),
        child: const Icon(FeatherIcons.feather, size: 28),
      );
    } else {
      return null;
    }
  }

  Future<bool> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => HarpyExitDialog(),
    ).then((bool pop) => pop == true);
  }

  Future<bool> _onWillPop(BuildContext context) async {
    // If the current pop request will close the application
    if (!Navigator.of(context).canPop()) {
      return _showExitDialog(context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ScrollDirectionListener(
      onScrollDirectionChanged: _onScrollDirectionChanged,
      child: WillPopScope(
        onWillPop: () => _onWillPop(context),
        child: HarpyScaffold(
          drawer: const HomeDrawer(),
          floatingActionButton: _buildFloatingActionButton(),
          body: BlocProvider<NewHomeTimelineBloc>(
            lazy: false,
            create: (_) => NewHomeTimelineBloc(),
            child: const HomeTimeline(),
            // child: BlocProvider<HomeTimelineBloc>(
            //   create: (BuildContext context) => HomeTimelineBloc(),
            //   child: TweetTimeline<HomeTimelineBloc>(
            //     headerSlivers: <Widget>[
            //       HarpySliverAppBar(
            //         title: 'Harpy',
            //         showIcon: true,
            //         floating: true,
            //         actions: _buildActions(),
            //       ),
            //     ],
            //     refreshIndicatorDisplacement: 80,
            //     onRefresh: (HomeTimelineBloc bloc) {
            //       bloc.add(const UpdateHomeTimelineEvent());
            //       return bloc.updateTimelineCompleter.future;
            //     },
            //     onLoadMore: (HomeTimelineBloc bloc) {
            //       bloc.add(const RequestMoreHomeTimelineEvent());
            //       return bloc.requestMoreCompleter.future;
            //     },
            //   ),
            // ),
          ),
        ),
      ),
    );
  }
}

class HomeTimeline extends StatefulWidget {
  const HomeTimeline();

  @override
  _HomeTimelineState createState() => _HomeTimelineState();
}

class _HomeTimelineState extends State<HomeTimeline> {
  ScrollController _controller;

  @override
  void initState() {
    super.initState();

    _controller = ScrollController();
  }

  void _blocListener(BuildContext context, HomeTimelineState state) {
    if (state is HomeTimelineResult && state.initialResults) {
      // scroll to the end after the list has been built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      });
    }
  }

  Widget _buildNewTweetsText(ThemeData theme) {
    return Container(
      padding: DefaultEdgeInsets.symmetric(horizontal: true),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(FeatherIcons.chevronsUp),
          defaultHorizontalSpacer,
          Text(
            'new tweets since last visit',
            style: theme.textTheme.subtitle2,
          ),
        ],
      ),
    );
  }

  Widget _tweetBuilder(
    ThemeData theme,
    HomeTimelineState state,
    TweetData tweet,
    int index,
  ) {
    if (state is HomeTimelineResult &&
        state.lastInitialTweet == tweet.idStr &&
        // todo: remove index != 0 check in favor of flag in state
        index != 0) {
      final List<Widget> children = <Widget>[
        TweetList.defaultTweetBuilder(tweet, index),
        defaultVerticalSpacer,
        _buildNewTweetsText(theme),
      ];

      return Column(
        mainAxisSize: MainAxisSize.min,
        // build the new tweets text above the last visible tweet if it exist
        children: state.includesLastVisibleTweet
            ? children.reversed.toList()
            : children,
      );
    } else {
      return TweetList.defaultTweetBuilder(tweet, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NewHomeTimelineBloc bloc = context.watch<NewHomeTimelineBloc>();
    final HomeTimelineState state = bloc.state;

    return BlocListener<NewHomeTimelineBloc, HomeTimelineState>(
      listener: _blocListener,
      child: ScrollDirectionListener(
        child: ScrollToStart(
          controller: _controller,
          child: RefreshIndicator(
            onRefresh: () async {},
            child: TweetList(
              state is HomeTimelineResult ? state.tweets : <TweetData>[],
              controller: _controller,
              tweetBuilder: (TweetData tweet, int index) =>
                  _tweetBuilder(theme, state, tweet, index),
              beginSlivers: const <Widget>[
                HomeAppBar(),
              ],
              endSlivers: <Widget>[
                if (state is HomeTimelineInitialLoading)
                  const SliverFillLoadingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
