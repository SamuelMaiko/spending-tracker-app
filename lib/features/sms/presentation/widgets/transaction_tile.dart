import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget for displaying individual transaction items
/// 
/// Shows transaction details with colored amounts (red for outgoing, green for incoming)
/// and categorization buttons for uncategorized transactions
class TransactionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime date;
  final double amount;
  final bool isIncome;
  final String? category;
  final bool needsCategorization;
  final VoidCallback? onCategorize;

  const TransactionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    required this.isIncome,
    this.category,
    this.needsCategorization = false,
    this.onCategorize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Transaction type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIncome ? Colors.green.shade100 : Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green.shade600 : Colors.blue.shade600,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('yyyy-MM-dd').format(date)} • ${DateFormat('HH:mm').format(date)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (category != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ] else if (needsCategorization) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Needs categorization',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Amount and categorize button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : ''}KSh ${NumberFormat('#,##0').format(amount.abs())}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIncome ? Colors.green.shade600 : Colors.black87,
                ),
              ),
              if (needsCategorization && onCategorize != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onCategorize,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Categorize',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Sample transaction data for testing
class SampleTransaction {
  final String title;
  final String subtitle;
  final DateTime date;
  final double amount;
  final bool isIncome;
  final String? category;
  final bool needsCategorization;

  const SampleTransaction({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    required this.isIncome,
    this.category,
    this.needsCategorization = false,
  });

  static List<SampleTransaction> getSampleTransactions() {
    return [
      SampleTransaction(
        title: 'M-PESA Paybill KPLC',
        subtitle: 'Electricity bill payment',
        date: DateTime(2024, 1, 20, 14, 30),
        amount: 150,
        isIncome: false,
        category: 'Bills',
      ),
      SampleTransaction(
        title: 'Matatu Fare - Route 46',
        subtitle: 'Transport payment',
        date: DateTime(2024, 1, 20, 8, 15),
        amount: 50,
        isIncome: false,
        needsCategorization: true,
      ),
      SampleTransaction(
        title: 'Salary Deposit - ABC Ltd',
        subtitle: 'Monthly salary',
        date: DateTime(2024, 1, 19, 9, 0),
        amount: 2000,
        isIncome: true,
        category: 'Income',
      ),
      SampleTransaction(
        title: 'Chapati Vendor',
        subtitle: 'Food purchase',
        date: DateTime(2024, 1, 19, 12, 45),
        amount: 25,
        isIncome: false,
        needsCategorization: true,
      ),
    ];
  }
}
