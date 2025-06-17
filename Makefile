DIRECTORIES := $(patsubst %/,%,$(sort $(dir $(wildcard */*))))
TYPES := conf sys service
IMAGES := $(foreach dir,$(foreach type,$(TYPES),$(subst /,_,$(wildcard $(DIRECTORIES)/$(type)))),$(dir).raw)

.PHONY: all $(DIRECTORIES) encrypt preqreqs clean
.SECONDEXPANSION:

# Build all images
all: $(IMAGES)

# Build all images related to service
$(DIRECTORIES): % : $(foreach type,$(TYPES),$(filter %_$(type).raw, $(IMAGES)))

# Build and encrypt images
encrypt: $(foreach image,$(IMAGES),encrypted/$(image))

# Create encrypted directory
encrypted:
	mkdir encrypted

# Write keyfile
keyfile:
	echo -n '${ENCRYPT_KEY}' > keyfile

# Encrypt built image
encrypted/%: % encrypted keyfile
	@echo Encrypting $@
	size=$(($(stat -c %s chrony_sys.raw) + 2048)) fallocate -l ${size} $@
	cryptsetup luksFormat $@ keyfile
	sudo cryptsetup -d keyfile open $@ $(subst .raw,,$(subst encrypted/,,$@))
	sudo dd if=$(subst encrypted/,,$@) of=/dev/mapper/$(subst .raw,,$(subst encrypted/,,$@)) status=progress
	sudo cryptsetup close $(subst .raw,,$(subst encrypted/,,$@))

# Build the erofs image
%.raw: $$(shell find $$(subst _,/,%))
	$(eval $@_SOURCE := $(subst _,/,$(subst .raw,,$@)))
	@echo "Making $@ with source $($@_SOURCE)"
	mkfs.erofs $@ $($@_SOURCE)

# Install prerequisites
preqreqs:
	apt install -y erofs-utils

# Clean up generated files
clean:
	rm -f *.raw
	rm -Rf output
	rm -Rf encrypted
	rm -f keyfile