class BanquetEvent {}

class SelectHallSlotEvent extends BanquetEvent {
  SelectHallSlotEvent({required this.hallName, required this.slotName});
  final String hallName;
  final String slotName;
}
