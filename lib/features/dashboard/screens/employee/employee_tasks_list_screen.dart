import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/primary_button.dart';

class EmployeeTasksListScreen extends ConsumerWidget {
  const EmployeeTasksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Fetch tasks from Firebase filtered by current employee ID

    final List<Map<String, dynamic>> tasks = [
      {
        'id': '1',
        'title': 'Customer Follow-up - Johnson Residence',
        'description': 'Followed up with John Doe for service renewal',
        'status': 'Pending',
        'amount': 75.00,
        'date': '2024-01-15',
        'customerName': 'John Doe',
        'priority': 'Medium',
      },
      {
        'id': '2',
        'title': 'Site Inspection - Downtown Office',
        'description': 'Generated 5 new leads from networking event',
        'status': 'Approved',
        'amount': 120.00,
        'date': '2024-01-16',
        'customerName': 'Downtown Corp',
        'priority': 'High',
      },
      {
        'id': '3',
        'title': 'Equipment Maintenance',
        'description': 'Referred Jane Smith for pest control services',
        'status': 'Rejected',
        'amount': 50.00,
        'date': '2024-01-14',
        'customerName': 'Maintenance Dept',
        'priority': 'Low',
      },
      {
        'id': '4',
        'title': 'Client Presentation',
        'description': 'Presented quarterly service plan to client',
        'status': 'Approved',
        'amount': 200.00,
        'date': '2024-01-13',
        'customerName': 'ABC Corporation',
        'priority': 'High',
      },
      {
        'id': '5',
        'title': 'Field Survey',
        'description': 'Surveyed 10 properties for potential service',
        'status': 'Pending',
        'amount': 90.00,
        'date': '2024-01-12',
        'customerName': 'Survey Team',
        'priority': 'Medium',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', true),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', false),
                    const SizedBox(width: 8),
                    _buildFilterChip('Approved', false),
                    const SizedBox(width: 8),
                    _buildFilterChip('Rejected', false),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Stats Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            'Total Tasks',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tasks.length.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            'Total Earnings',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${_calculateTotalEarnings(tasks)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Task List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _buildTaskItem(context, task);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
      ),
      onSelected: (bool value) {
        // Handle filter selection
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, Map<String, dynamic> task) {
    Color priorityColor;
    switch (task['priority']) {
      case 'High':
        priorityColor = AppColors.error;
        break;
      case 'Medium':
        priorityColor = Colors.orange;
        break;
      case 'Low':
        priorityColor = AppColors.success;
        break;
      default:
        priorityColor = AppColors.textNeutral;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        _showTaskDetails(context, task);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              StatusBadge(status: task['status']),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            task['description'],
            style: const TextStyle(fontSize: 14, color: AppColors.textNeutral),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.textNeutral,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task['customerName'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textNeutral,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: priorityColor.withOpacity(0.3)),
                ),
                child: Text(
                  task['priority'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: priorityColor,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                '\$${task['amount']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.textNeutral,
              ),
              const SizedBox(width: 4),
              Text(
                task['date'],
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textNeutral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateTotalEarnings(List<Map<String, dynamic>> tasks) {
    double total = 0;
    for (var task in tasks) {
      if (task['status'] == 'Approved') {
        total += task['amount'];
      }
    }
    return total;
  }

  void _showTaskDetails(BuildContext context, Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      StatusBadge(status: task['status']),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Task Details
                  _buildDetailRow('Description:', task['description']),
                  _buildDetailRow('Customer:', task['customerName']),
                  _buildDetailRow('Date:', task['date']),
                  _buildDetailRow('Priority:', task['priority']),
                  _buildDetailRow('Amount:', '\$${task['amount']}'),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (task['status'] == 'Pending')
                    PrimaryButton(
                      text: 'Edit Task',
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Navigate to edit task
                      },
                    ),

                  if (task['status'] == 'Rejected')
                    Column(
                      children: [
                        Text(
                          'Reason for rejection: Insufficient evidence provided.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Resubmit task
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(color: AppColors.error),
                          ),
                          child: const Text(
                            'Resubmit with Updates',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textNeutral),
          ),
        ],
      ),
    );
  }
}
