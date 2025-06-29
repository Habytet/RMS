import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:token_manager/screens/notification_screen/notification_bloc.dart';
import 'package:token_manager/screens/notification_screen/notification_event.dart';
import 'package:token_manager/screens/notification_screen/notification_state.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({required this.bloc, super.key});
  final NotificationBloc bloc;

  @override
  State<StatefulWidget> createState() => NotificationViewScreenState();
}

class NotificationViewScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    widget.bloc.add(GetNotificationEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications')),
      body: BlocBuilder(
          bloc: widget.bloc,
          buildWhen: (preState, currState) =>
              currState is NotificationSuccessState,
          builder: (context, state) {
            return ListView.builder(
              itemCount: widget.bloc.notifications?.length ?? 0,
              itemBuilder: (context, index) {
                final notification = widget.bloc.notifications![index];
                return ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text(notification.title ?? 'No Title'),
                  subtitle: Text(notification.message ?? 'No Message'),
                  trailing: Text(
                    notification.createdAt != null
                        ? timeAgo(notification.createdAt!)
                        : '',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              },
            );
          }),
    );
  }

  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
