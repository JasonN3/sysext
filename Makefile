DIRECTORIES := $(patsubst %/,%,$(sort $(dir $(wildcard */*))))
TYPES := conf sys service
IMAGES := $(foreach dir,$(foreach type,$(TYPES),$(subst /,_,$(wildcard $(DIRECTORIES)/$(type)))),$(dir).raw)

.PHONY: all $(DIRECTORIES) encrypt prereqs clean
.SECONDEXPANSION:

# Build all images
all: $(IMAGES)

# Build all images related to service
$(DIRECTORIES): % : $(foreach type,$(TYPES),$(filter %_$(type).raw, $(IMAGES)))

# Build and encrypt images
encrypt: $(foreach image,$(IMAGES),encrypted/$(image))

# Create encrypted directory
encrypted:
	mkdir -p encrypted

# Write keyfile
keyfile:
	@echo -n '${ENCRYPT_KEY}' > keyfile

# Encrypt built image
encrypted/%: % encrypted keyfile
	@echo Encrypting $@
	$(eval $<_SIZE := $(shell stat -c %s $<))
	# Disk size + LUKS + GPT
	fallocate -l $$(( $($<_SIZE) + 16777216 + 16384)) $@
	sudo parted $@ mklabel gpt
	sudo parted $@ mkpart primary 0% 100%
	ln -s $$(sudo losetup -P --show -f $@)p1 disk_image_$<
	ls -l disk_image_$<
	ls -l /dev/loop*
	sudo dd if=/dev/zero if=disk_image_$< status=progress
	sudo cryptsetup -q luksFormat disk_image_$< keyfile
	sudo cryptsetup -d keyfile open disk_image_$< $(subst .raw,,$<)
	sudo dd if=$($<) of=/dev/mapper/$(subst .raw,,$<) status=progress
	sudo cryptsetup close disk_image_$<
	sudo losetup -d $$(readlink disk_image_$< | sed 's/p1$//')

# Build the erofs image
%.raw: $$(shell find $$(subst _,/,%))
	$(eval $@_SOURCE := $(subst _,/,$(subst .raw,,$@)))
	@echo "Making $@ with source $($@_SOURCE)"
	mkfs.erofs $@ $($@_SOURCE)

# Install prerequisites
prereqs:
	apt install -y erofs-utils cryptsetup-bin

# Clean up generated files
clean:
	rm -f *.raw
	rm -Rf output
	rm -Rf encrypted
	rm -f keyfile