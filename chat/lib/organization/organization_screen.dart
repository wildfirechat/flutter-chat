import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/widget/portrait.dart';
import '../default_portrait_provider.dart';
import '../user_info_widget.dart';
import 'organization_view_model.dart';

class OrganizationScreen extends StatefulWidget {
  final int? initialOrganizationId;

  const OrganizationScreen({super.key, this.initialOrganizationId});

  @override
  _OrganizationScreenState createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  late OrganizationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = OrganizationViewModel();
    _viewModel.loadInitialData(organizationId: widget.initialOrganizationId);
  }

  Widget _buildBreadcrumbs() {
    return Consumer<OrganizationViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.breadcrumbPath.isEmpty) return const SizedBox.shrink();

        List<Widget> breadcrumbWidgets = [];
        for (int i = 0; i < viewModel.breadcrumbPath.length; i++) {
          final org = viewModel.breadcrumbPath[i];
          breadcrumbWidgets.add(
            InkWell(
              onTap: () {
                if (i < viewModel.breadcrumbPath.length - 1) {
                  viewModel.navigateToOrganization(org);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                child: Text(
                  org.name ?? 'Unnamed',
                  style: TextStyle(
                    color: i == viewModel.breadcrumbPath.length - 1 ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).colorScheme.primary,
                    fontWeight: i == viewModel.breadcrumbPath.length - 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
          if (i < viewModel.breadcrumbPath.length - 1) {
            breadcrumbWidgets.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(Icons.chevron_right, size: 18.0, color: Colors.grey[700]),
            ));
          }
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(children: breadcrumbWidgets),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<OrganizationViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(viewModel.appBarTitle ?? '组织结构'),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(),
                const Divider(height: 1),
                if (viewModel.isLoading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (viewModel.error != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(viewModel.error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              onPressed: () => viewModel.retryLoadData(),
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                else if (viewModel.currentOrganizationDetails == null)
                  const Expanded(child: Center(child: Text('No organization data available.')))
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      children: [
                        // List Sub-Organizations
                        if (viewModel.currentOrganizationDetails!.subOrganizations != null && viewModel.currentOrganizationDetails!.subOrganizations!.isNotEmpty)
                          ...viewModel.currentOrganizationDetails!.subOrganizations!.map((subOrg) {
                            return ListTile(
                              leading: Icon(Icons.corporate_fare, color: Theme.of(context).colorScheme.secondary),
                              title: Text(subOrg.name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => viewModel.navigateToOrganization(subOrg),
                            );
                          }),

                        // List Members
                        if (viewModel.currentOrganizationDetails!.employees != null && viewModel.currentOrganizationDetails!.employees!.isNotEmpty)
                          ...viewModel.currentOrganizationDetails!.employees!.map((emp) {
                            return ListTile(
                              leading: Portrait(emp.portraitUrl ?? WFPortraitProvider.instance.userDefaultPortrait(emp.toUserInfo()), Config.defaultUserPortrait),
                              title: Text(emp.name),
                              // subtitle: Text(emp.alias ?? emp.id?.toString() ?? 'No ID/Alias'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserInfoWidget(emp.employeeId),
                                  ),
                                );
                              },
                            );
                          }),

                        // Empty state if both are empty (or only one type exists and is empty)
                        if ((viewModel.currentOrganizationDetails!.subOrganizations == null || viewModel.currentOrganizationDetails!.subOrganizations!.isEmpty) &&
                            (viewModel.currentOrganizationDetails!.employees == null || viewModel.currentOrganizationDetails!.employees!.isEmpty))
                          ListTile(
                            title: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Text('No sub-units or members in this organization.', style: TextStyle(color: Colors.grey[600])),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
