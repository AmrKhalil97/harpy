import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

class ListTimeline extends ConsumerWidget {
  const ListTimeline({
    required this.listId,
    required this.listName,
    this.beginSlivers = const [],
    this.endSlivers = const [],
    this.scrollPosition = 0,
  });

  final String listId;
  final String listName;
  final List<Widget> beginSlivers;
  final List<Widget> endSlivers;
  final int scrollPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return Timeline(
      provider: listTimelineProvider(listId),
      beginSlivers: [
        ...beginSlivers,
        ListTimelineTopActions(
          listId: listId,
          listName: listName,
        ),
      ],
      scrollPosition: scrollPosition,
      onChangeFilter: () => router.pushNamed(
        ListTimelineFilter.name,
        params: {'listId': listId},
        queryParams: {'name': listName},
      ),
    );
  }
}
