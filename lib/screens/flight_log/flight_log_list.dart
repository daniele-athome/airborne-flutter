
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import '../../helpers/cupertinoplus.dart';
import '../../models/flight_log_models.dart';
import '../../services/flight_log_services.dart';

final Logger _log = Logger((FlightLogItem).toString());

class FlightLogList extends StatefulWidget {
  const FlightLogList({
    Key? key,
    required this.logBookService,
    required this.onTapItem,
  })  : super(key: key);

  final FlightLogBookService logBookService;
  final Function(BuildContext context, FlightLogItem item) onTapItem;

  @override
  _FlightLogListState createState() => _FlightLogListState();
}

class _FlightLogListState extends State<FlightLogList> {

  final _hoursFormatter = NumberFormat.decimalPattern();
  // TODO locale
  final _dateFormatter = DateFormat('dd/MM/yyyy');
  final _pagingController = PagingController<int, FlightLogItem>(
    firstPageKey: 1,
  );
  var _firstTime = true;

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) => _fetchPage(pageKey));
    super.initState();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      if (_firstTime) {
        await widget.logBookService.reset();
        _firstTime = false;
      }

      final items = await widget.logBookService.fetchItems();
      final page = items.toList(growable: false).reversed.toList(growable: false);

      if (widget.logBookService.hasMoreData()) {
        _pagingController.appendPage(page, pageKey + 1);
      }
      else {
        _pagingController.appendLastPage(page);
      }
    }
    catch (error, stacktrace) {
      _log.warning('error loading log book data', error, stacktrace);
      _pagingController.error = error;
    }
  }

  Future<void> _refresh() async {
    _firstTime = true;
    return Future.sync(() => _pagingController.refresh());
  }

  String _buildLocationName(FlightLogItem item) => (item.origin != item.destination) ?
        '${item.origin} – ${item.destination}' : item.origin;

  String _buildHours(FlightLogItem item) =>
      '${_hoursFormatter.format(item.startHour)} – ${_hoursFormatter.format(item.endHour)}';

  String _buildTime(FlightLogItem item) => '${((item.endHour - item.startHour)*60).round().toString()}′';

  Widget _buildListItem(BuildContext context, FlightLogItem item, int index) {
    final dateStyle = (isCupertino(context) ?
      CupertinoTheme.of(context).textTheme.textStyle :
      Theme.of(context).textTheme.bodyText1!).copyWith(
        fontSize: 16,
        // TODO do we need this? -- fontWeight: FontWeight.bold,
      );
    final subtitleStyle = isCupertino(context) ?
      CupertinoTheme.of(context).textTheme.textStyle :
      Theme.of(context).textTheme.subtitle1!.copyWith(color: Theme.of(context).textTheme.caption!.color);
    final pilotStyle = (isCupertino(context) ?
      CupertinoTheme.of(context).textTheme.textStyle :
      Theme.of(context).textTheme.bodyText2!).copyWith(
        fontSize: 17,
        // TODO do we need this? -- fontWeight: FontWeight.w300,
      );
    final timeStyle = (isCupertino(context) ?
      CupertinoTheme.of(context).textTheme.textStyle :
      Theme.of(context).textTheme.bodyText2!).copyWith(
        fontSize: 20,
      );

    final listItem = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(_dateFormatter.format(item.date), style: dateStyle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(PlatformIcons(context).locationSolid, color: Colors.red, size: 18),
                      const SizedBox(width: 4),
                      Text(_buildLocationName(item), style: subtitleStyle),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(PlatformIcons(context).clockSolid, color: Colors.blue, size: 18),
                      const SizedBox(width: 4),
                      Text(_buildHours(item), style: subtitleStyle),
                    ],
                  ),
                ),
              ],
            )
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(item.pilotName,style: pilotStyle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (item.fuel != null && item.fuel! > 0) const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.local_gas_station, color: Colors.green, size: 24),
                      ),
                      Text(_buildTime(item), style: timeStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isCupertino(context)) {
      return CupertinoInkWell(
        onPressed: () => widget.onTapItem(context, item),
        child: listItem,
      );
    }
    else {
      return InkWell(
        onTap: () => widget.onTapItem(context, item),
        child: listItem,
      );
    }
  }

  /// FIXME using PagedSliverList within a CustomScrollView for Material leads to errors
  @override
  Widget build(BuildContext context) {
    // TODO test scrolling phytics with no content
    if (isCupertino(context)) {
      return CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: () => _refresh(),
          ),
          PagedSliverList.separated(
            pagingController: _pagingController,
            separatorBuilder: (context, index) => isCupertino(context) ?
            buildCupertinoFormRowDivider(context, true) : const Divider(height: 0),
            builderDelegate: PagedChildBuilderDelegate<FlightLogItem>(
              itemBuilder: _buildListItem,
              // TODO firstPageErrorIndicatorBuilder:
              // TODO firstPageProgressIndicatorBuilder:
              // TODO noItemsFoundIndicatorBuilder:
              // TODO noMoreItemsIndicatorBuilder:
              firstPageProgressIndicatorBuilder: (context) => const CupertinoActivityIndicator(radius: 20),
              newPageProgressIndicatorBuilder: (context) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CupertinoActivityIndicator(radius: 16),
              ),
            ),
          ),
        ],
      );
    }
    else {
      return RefreshIndicator(
        onRefresh: () => _refresh(),
        child: PagedListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          pagingController: _pagingController,
          separatorBuilder: (context, index) => isCupertino(context) ?
          buildCupertinoFormRowDivider(context, true) : const Divider(height: 0),
          builderDelegate: PagedChildBuilderDelegate<FlightLogItem>(
            itemBuilder: _buildListItem,
            // TODO firstPageErrorIndicatorBuilder:
            // TODO firstPageProgressIndicatorBuilder:
            // TODO noItemsFoundIndicatorBuilder:
            // TODO noMoreItemsIndicatorBuilder:
            // TODO firstPageProgressIndicatorBuilder:
            // TODO newPageProgressIndicatorBuilder:
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

}
