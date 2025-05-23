import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/viewmodel/search_view_model.dart';

// 需要 StatefulWidget 才能保持 SearchVieModel，实现实时搜索
class SearchPortalResultView extends StatefulWidget {
  final String query;

  const SearchPortalResultView(this.query, {super.key});

  @override
  State<SearchPortalResultView> createState() => _SearchPortalResultViewState();
}

class _SearchPortalResultViewState extends State<SearchPortalResultView> {
  SearchViewModel? _searchViewModel;

  @override
  Widget build(BuildContext context) {
    _searchViewModel?.search(widget.query);
    return ChangeNotifierProvider<SearchViewModel>(
      create: (_) {
        var vm = SearchViewModel();
        vm.search(widget.query);
        _searchViewModel = vm;
        return vm;
      },
      child: Consumer<SearchViewModel>(
        builder: (context, vm, child) {
          return ListView.builder(
            itemCount: vm.searchedUsers.length + vm.searchedFriends.length,
            itemBuilder: (context, index) {
              String title = '';
              String desc = '';
              if (index < vm.searchedUsers.length) {
                title = vm.searchedUsers[index].getReadableName();
                desc = '用户';
              } else if (index < vm.searchedUsers.length + vm.searchedFriends.length) {
                title = vm.searchedFriends[index - vm.searchedUsers.length].getReadableName();
                desc = '好友';
              }
              return ListTile(
                title: Text(title),
                subtitle: Text(desc),
              );
            },
          );
        },
      ),
    );
  }
}
