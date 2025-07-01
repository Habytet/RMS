import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:token_manager/models/hall.dart';
import 'package:token_manager/models/slot.dart';
import 'package:token_manager/screens/banquet/banquet_event.dart';
import 'package:token_manager/screens/banquet/banquet_state.dart';

class BanquetBloc extends Bloc<BanquetEvent, BanquetState> {
  BanquetBloc() : super(BanquetState()) {
    on<SelectHallSlotEvent>(_selectHallSlotEvent);
  }
  List<HallInfo> selectedHalls = <HallInfo>[];

  Future<void> _selectHallSlotEvent(
      SelectHallSlotEvent event, Emitter<BanquetState> emit) async {
    final index = selectedHalls.indexWhere((h) => h.name == event.hallName);
    if (index != -1) {
      List<Slot> updatedSlots = List.from(selectedHalls[index].slots);
      final slotIndex =
          updatedSlots.indexWhere((s) => s.label == event.slotName);
      if (slotIndex != -1) {
        updatedSlots.removeAt(slotIndex);
      } else {
        updatedSlots.add(Slot(hallName: event.hallName, label: event.slotName));
      }
      selectedHalls[index] =
          HallInfo(name: event.hallName, slots: updatedSlots);
      if (selectedHalls[index].slots.isEmpty) {
        selectedHalls.removeAt(index);
      }
    } else {
      selectedHalls.add(HallInfo(name: event.hallName, slots: [
        Slot(hallName: event.hallName, label: event.slotName),
      ]));
      if (index >= 0) {
        if (selectedHalls[index].slots.isEmpty) {
          selectedHalls.removeAt(index);
        }
      }
    }
    emit(RefreshBottomSheetState());
  }

  bool isSelectedSlots({required String hallName, required String slot}) {
    for (int i = 0; i < selectedHalls.length; i++) {
      if (selectedHalls[i].name == hallName) {
        final List<Slot> slots = selectedHalls[i].slots;
        for (int j = 0; j < slots.length; j++) {
          if (slots[j].label == slot) {
            return true;
          }
        }
      }
    }
    return false;
  }

  String selectedHallSlot() {
    String info = '';
    for (int i = 0; i < selectedHalls.length; i++) {
      info = info.isNotEmpty
          ? '$info\n${selectedHalls[i].name}'
          : '${selectedHalls[i].name}';
      final List<Slot> slots = selectedHalls[i].slots;
      for (int j = 0; j < slots.length; j++) {
        info = '$info\n  ${slots[j].label}';
      }
    }
    return info;
  }
}
